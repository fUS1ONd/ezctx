import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/error/app_exception.dart';
import 'audio_chunking_service.dart';
import 'chunk_state.dart';
import 'key_pool.dart';
import 'normalized_audio_file.dart';
import 'transcription_options.dart';
import 'transcription_provider.dart';
import 'transcription_result.dart';

// ---------------------------------------------------------------------------
// Вспомогательный семафор: ограничивает количество одновременных операций.
// ---------------------------------------------------------------------------

class _Semaphore {
  _Semaphore(this._maxConcurrent);

  final int _maxConcurrent;
  int _running = 0;
  final _queue = <Completer<void>>[];

  Future<T> run<T>(Future<T> Function() fn) async {
    if (_running >= _maxConcurrent) {
      final waiter = Completer<void>();
      _queue.add(waiter);
      await waiter.future;
    }
    _running++;
    try {
      return await fn();
    } finally {
      _running--;
      if (_queue.isNotEmpty) _queue.removeAt(0).complete();
    }
  }
}

// ---------------------------------------------------------------------------
// Состояния ChunkedTranscriptionController (sealed).
// ---------------------------------------------------------------------------

/// Базовое состояние контроллера чанкованной транскрибации.
sealed class ChunkedState {
  const ChunkedState();
}

/// Контроллер простаивает (ничего не запущено).
class ChunkedIdle extends ChunkedState {
  const ChunkedIdle();
}

/// Идёт разбивка файла на чанки (ffmpeg).
class ChunkedSplitting extends ChunkedState {
  const ChunkedSplitting();
}

/// Чанки отправляются в Groq (параллельно, ≤ maxConcurrent).
class ChunkedProcessing extends ChunkedState {
  final List<ChunkState> chunks;
  final int completedCount;
  final int totalCount;

  const ChunkedProcessing({
    required this.chunks,
    required this.completedCount,
    required this.totalCount,
  });

  /// Прогресс от 0.0 до 1.0.
  double get progress => totalCount == 0 ? 0.0 : completedCount / totalCount;
}

/// Все чанки успешно транскрибированы; результат собран.
class ChunkedSuccess extends ChunkedState {
  final TranscriptionResult result;
  const ChunkedSuccess({required this.result});
}

/// Произошла ошибка (после всех retry или неретраибельная).
class ChunkedError extends ChunkedState {
  final String message;

  /// true — пользователь может нажать «повторить»; false — нет (AuthException).
  final bool retryable;

  const ChunkedError({required this.message, required this.retryable});
}

/// API-ключ не настроен.
class ChunkedMissingKey extends ChunkedState {
  const ChunkedMissingKey();
}

// ---------------------------------------------------------------------------
// Контроллер.
// ---------------------------------------------------------------------------

/// ChangeNotifier, управляющий пайплайном транскрибации большого файла:
/// разбивка через [AudioChunkingService] → параллельная отправка (≤ maxConcurrent) →
/// retry на транзиентных ошибках через [KeyPool] → сборка текста с таймкодами →
/// удаление tmp-чанков.
class ChunkedTranscriptionController extends ChangeNotifier {
  ChunkedTranscriptionController({
    required KeyPool pool,
    required TranscriptionProvider apiService,
    required AudioChunkingService chunkingService,
    @visibleForTesting Duration Function(int attempt)? retryDelay,
  })  : _pool = pool,
        _api = apiService,
        _chunkingService = chunkingService,
        _retryDelay = retryDelay ?? _defaultRetryDelay;

  static Duration _defaultRetryDelay(int attempt) =>
      Duration(seconds: 5 * (1 << (attempt - 1).clamp(0, 5)));

  final KeyPool _pool;
  final TranscriptionProvider _api;
  final AudioChunkingService _chunkingService;
  final Duration Function(int attempt) _retryDelay;

  ChunkedState _state = const ChunkedIdle();
  ChunkedState get state => _state;

  // Список результатов чанков; индексируется по номеру чанка.
  late List<TranscriptionResult?> _results;

  // Мутабельный список состояний чанков для обновления из параллельных Future.
  late List<ChunkState> _chunkStates;

  // Счётчик завершённых чанков.
  int _completedCount = 0;

  void _set(ChunkedState s) {
    _state = s;
    notifyListeners();
  }

  /// Обновить состояние одного чанка и уведомить слушателей.
  void _updateChunkState(int index, ChunkState chunkState) {
    _chunkStates[index] = chunkState;
    _set(ChunkedProcessing(
      chunks: List.unmodifiable(_chunkStates),
      completedCount: _completedCount,
      totalCount: _chunkStates.length,
    ));
  }

  /// Запустить транскрибацию [file].
  ///
  /// Переводит контроллер через ChunkedSplitting → ChunkedProcessing →
  /// ChunkedSuccess / ChunkedError / ChunkedMissingKey.
  Future<void> start(
    NormalizedAudioFile file, {
    TranscriptionOptions options = const TranscriptionOptions.defaults(),
  }) async {
    // Явный сброс при каждом вызове start() — обеспечивает корректный счётчик
    // при повторном использовании того же экземпляра контроллера (кнопка «Повторить»).
    _completedCount = 0;
    _set(const ChunkedSplitting());

    // Проверяем наличие ключей в пуле.
    if (_pool.allKeys.isEmpty) {
      _set(const ChunkedMissingKey());
      return;
    }

    // Разбиваем файл на равные чанки.
    List<File> chunkFiles;
    try {
      chunkFiles = await _chunkingService.split(file.path, file.durationSeconds);
    } catch (e) {
      _set(ChunkedError(
        message: e is AppException ? e.message : e.toString(),
        retryable: true,
      ));
      return;
    }

    // Защита от пустого списка чанков: теоретически возможно при нулевой длительности файла.
    // Без этой проверки chunkFiles.length == 0 приведёт к делению на ноль (double.infinity),
    // что даст таймкоды вида [Infinity:NaN:NaN] в итоговом тексте.
    if (chunkFiles.isEmpty) {
      _set(ChunkedError(
        message: 'Не удалось разбить файл на чанки (пустой результат)',
        retryable: true,
      ));
      return;
    }

    // Используем реальное количество чанков от ffmpeg для точных таймкодов.
    // chunkFiles.length >= 1 гарантировано проверкой выше.
    final chunkDuration = file.durationSeconds / chunkFiles.length;

    final n = chunkFiles.length;
    _chunkStates = List<ChunkState>.generate(n, (i) => ChunkWaiting(i));
    _results = List<TranscriptionResult?>.filled(n, null);
    _completedCount = 0;

    _set(ChunkedProcessing(
      chunks: List.unmodifiable(_chunkStates),
      completedCount: 0,
      totalCount: n,
    ));

    // Конкурентность определяется политикой провайдера (см. TranscriptionProvider.concurrencyFor) —
    // контроллер провайдеро-независим. Для Groq результат идентичен прежнему
    // clamp(1, kMaxConcurrentChunks): нижний порог 1 предотвращает деление на ноль
    // и гарантирует обработку хотя бы одного чанка, верхний — ограничен kMaxConcurrentChunks.
    final concurrency = _api.concurrencyFor(_pool.aliveKeyCount);
    final semaphore = _Semaphore(concurrency);

    try {
      await Future.wait(
        chunkFiles.asMap().entries.map(
          (entry) => semaphore.run(
            () => _processChunk(entry.key, entry.value, options),
          ),
        ),
      );
    } on AuthException catch (e) {
      _set(ChunkedError(message: e.message, retryable: false));
      return;
    } catch (e) {
      _set(ChunkedError(
        message: e is AppException ? e.message : e.toString(),
        retryable: true,
      ));
      return;
    } finally {
      // Удаляем tmp-чанки независимо от результата.
      for (final f in chunkFiles) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }

    // Все чанки успешны — собираем результат.
    // Защита: если какой-то слот остался null (теоретически не должно быть
    // после Future.wait без исключений), заменяем на пустой результат вместо
    // краша при force-unwrap r!.
    final assembled = _assembleResult(
      _results
          .map((r) => r ?? TranscriptionResult.empty())
          .toList(),
      chunkDuration,
    );
    _set(ChunkedSuccess(result: assembled));
  }

  /// Транскрибирует один чанк с retry-логикой через пул ключей.
  ///
  /// При [RateLimitException] сообщает пулу о блокировке и пробует следующий ключ.
  /// При [AuthException] — пробрасывает немедленно.
  /// При [NetworkException] — экспоненциальная задержка, до [_maxAttempts] попыток.
  Future<TranscriptionResult> _processChunk(
    int index,
    File file,
    TranscriptionOptions options,
  ) async {
    final bytes = await file.readAsBytes();
    final filename = 'chunk_${index.toString().padLeft(3, '0')}.ogg';

    // Отдельные счётчики для разных типов ошибок: смешивать нельзя,
    // иначе при 5 rate-limit попытках (смена ключей) следующая сетевая ошибка
    // немедленно завершает чанк без реальных ретраев по сети.
    int networkAttempt = 0;
    int rateLimitAttempt = 0;
    const maxAttempts = 10;

    while (networkAttempt < maxAttempts && rateLimitAttempt < maxAttempts) {
      // Показываем статус ожидания ключа если все заблокированы.
      if (_pool.aliveKeyCount == 0) {
        _updateChunkState(index, ChunkWaitingForKey(index));
      } else {
        _updateChunkState(index, ChunkUploading(index));
      }

      final key = await _pool.acquireKey();
      _updateChunkState(index, ChunkUploading(index));

      try {
        final result = await _api.transcribeChunk(
          bytes: bytes,
          filename: filename,
          apiKey: key,
          options: options,
        );

        _results[index] = result;
        _chunkStates[index] = ChunkDone(index, text: result.text);
        _completedCount++;
        _set(ChunkedProcessing(
          chunks: List.unmodifiable(_chunkStates),
          completedCount: _completedCount,
          totalCount: _chunkStates.length,
        ));
        return result;
      } on AllKeysBlockedException {
        // Все ключи заблокированы и таймаут (10 мин) истёк — пробрасываем напрямую,
        // чтобы Future.wait→catch вывел понятное сообщение, а не «Неизвестная ошибка».
        rethrow;
      } on KeyExhaustedException {
        // Кредиты ключа исчерпаны (Deepgram HTTP 402) — ключ выводится из ротации
        // навсегда. Счётчики networkAttempt/rateLimitAttempt НЕ инкрементируются:
        // это не транзиентная ошибка, а постоянная. Следующий acquireKey() вернёт
        // другой живой ключ или бросит AllKeysBlockedException.
        _pool.reportExhausted(key);
        _updateChunkState(index, ChunkRetrying(index, attempt: 0));
        // Продолжаем цикл — без rethrow.
      } on RateLimitException catch (e) {
        rateLimitAttempt++;
        // Сообщаем пулу о блокировке ключа на указанное время.
        _pool.reportRateLimited(key, e.retryAfterSeconds);
        if (rateLimitAttempt >= maxAttempts) {
          // Исчерпаны все попытки из-за rate-limit — сообщаем корректную причину.
          throw const NetworkException('Превышено число попыток (rate limit)');
        }
        _updateChunkState(index, ChunkRetrying(index, attempt: rateLimitAttempt));
        // Не ждём явно: следующая итерация вызовет acquireKey() и дождётся живого ключа.
      } on AuthException {
        // Неверный ключ — пробрасываем немедленно без ретрая.
        rethrow;
      } on NetworkException {
        networkAttempt++;
        if (networkAttempt >= maxAttempts) {
          throw const NetworkException('Превышено максимальное число попыток');
        }
        _updateChunkState(index, ChunkRetrying(index, attempt: networkAttempt));
        await Future.delayed(_retryDelay(networkAttempt));
      }
    }

    throw const NetworkException('Превышено максимальное число попыток');
  }

  /// Собирает финальный [TranscriptionResult] из результатов чанков.
  ///
  /// Для каждого сегмента вычисляет абсолютное время:
  /// `absoluteStart = chunkIndex * chunkDuration + segment.start`.
  /// [text] форматирует в `[HH:MM:SS] segment.text` (timestamped).
  /// [plainText] содержит тот же текст без временных меток (Bug-2).
  TranscriptionResult _assembleResult(
    List<TranscriptionResult> results,
    double chunkDuration,
  ) {
    // timestamped-буфер: `[HH:MM:SS] текст`
    final buffer = StringBuffer();
    // plain-буфер: чистый текст без таймкодов для переключателя вида
    final plainBuffer = StringBuffer();
    final allSegments = <TranscriptionSegment>[];
    double totalDuration = 0.0;
    String language = '';

    for (var i = 0; i < results.length; i++) {
      final r = results[i];
      totalDuration += r.duration;
      if (language.isEmpty) language = r.language;

      if (r.segments.isNotEmpty) {
        // Есть сегменты — собираем с таймкодами.
        for (final seg in r.segments) {
          final absoluteStart = i * chunkDuration + seg.start;
          final ts = _formatTimecode(absoluteStart);
          buffer.write('[$ts] ${seg.text.trim()}\n');
          plainBuffer.write('${seg.text.trim()}\n');
          allSegments.add(TranscriptionSegment(
            start: absoluteStart,
            end: i * chunkDuration + seg.end,
            text: seg.text,
          ));
        }
      } else {
        // Нет сегментов — используем весь текст чанка с таймкодом начала.
        final offsetStart = i * chunkDuration;
        final ts = _formatTimecode(offsetStart);
        buffer.write('[$ts] ${r.text.trim()}\n');
        plainBuffer.write('${r.text.trim()}\n');
      }
    }

    return TranscriptionResult(
      text: buffer.toString().trimRight(),
      plainText: plainBuffer.toString().trimRight(),
      language: language,
      duration: totalDuration,
      words: const [],
      segments: allSegments,
    );
  }

  /// Форматирует секунды в строку [HH:MM:SS].
  static String _formatTimecode(double totalSeconds) {
    final secs = totalSeconds.round();
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    final s = secs % 60;
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }
}
