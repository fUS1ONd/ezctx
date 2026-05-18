import 'dart:async';
import 'dart:io';
import 'dart:math' show min;

import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../../core/error/app_exception.dart';
import 'audio_chunking_service.dart';
import 'chunk_state.dart';
import 'groq_key_pool.dart';
import 'selected_audio_file.dart';
import 'transcription_result.dart';
import 'groq_api_service.dart';

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
/// retry на транзиентных ошибках через [GroqKeyPool] → сборка текста с таймкодами →
/// удаление tmp-чанков.
class ChunkedTranscriptionController extends ChangeNotifier {
  ChunkedTranscriptionController({
    required GroqKeyPool pool,
    required GroqApiService apiService,
    required AudioChunkingService chunkingService,
  })  : _pool = pool,
        _api = apiService,
        _chunkingService = chunkingService;

  final GroqKeyPool _pool;
  final GroqApiService _api;
  final AudioChunkingService _chunkingService;

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
  Future<void> start(SelectedAudioFile file) async {
    _set(const ChunkedSplitting());

    // Проверяем наличие ключей в пуле.
    if (_pool.allKeys.isEmpty) {
      _set(const ChunkedMissingKey());
      return;
    }

    // Получаем метаданные для вычисления chunkDuration.
    double chunkDuration = kChunkDurationSeconds;
    try {
      final metadata = await _chunkingService.getMetadata(file.path);
      if (metadata.durationSeconds > 0) {
        // chunkDuration — постоянная величина; метаданные нужны только для
        // проверки длительности при необходимости. Используем константу.
        chunkDuration = kChunkDurationSeconds;
      }
    } catch (_) {
      // Ошибка метаданных не блокирует: используем константу.
    }

    // Разбиваем файл на чанки.
    List<File> chunkFiles;
    try {
      chunkFiles = await _chunkingService.split(file.path);
    } catch (e) {
      _set(ChunkedError(
        message: e is AppException ? e.message : e.toString(),
        retryable: true,
      ));
      return;
    }

    final n = chunkFiles.length;
    _chunkStates = List<ChunkState>.generate(n, (i) => ChunkWaiting(i));
    _results = List<TranscriptionResult?>.filled(n, null);
    _completedCount = 0;

    _set(ChunkedProcessing(
      chunks: List.unmodifiable(_chunkStates),
      completedCount: 0,
      totalCount: n,
    ));

    // Семафор с количеством слотов = min(живых ключей, лимита параллельности).
    final concurrency = min(
      _pool.aliveKeyCount.clamp(1, AppConstants.kMaxConcurrentChunks),
      AppConstants.kMaxConcurrentChunks,
    );
    final semaphore = _Semaphore(concurrency);

    try {
      await Future.wait(
        chunkFiles.asMap().entries.map(
          (entry) => semaphore.run(
            () => _processChunk(entry.key, entry.value),
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
    final assembled = _assembleResult(
      _results.map((r) => r!).toList(),
      chunkDuration,
    );
    _set(ChunkedSuccess(result: assembled));
  }

  /// Транскрибирует один чанк с retry-логикой через пул ключей.
  ///
  /// При [RateLimitException] сообщает пулу о блокировке и пробует следующий ключ.
  /// При [AuthException] — пробрасывает немедленно.
  /// При [NetworkException] — экспоненциальная задержка, до [_maxAttempts] попыток.
  Future<void> _processChunk(int index, File file) async {
    final bytes = await file.readAsBytes();
    final filename = 'chunk_${index.toString().padLeft(3, '0')}.mp3';

    int attempt = 0;
    const maxAttempts = 10;

    while (attempt < maxAttempts) {
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
        );

        _results[index] = result;
        _chunkStates[index] = ChunkDone(index, text: result.text);
        _completedCount++;
        _set(ChunkedProcessing(
          chunks: List.unmodifiable(_chunkStates),
          completedCount: _completedCount,
          totalCount: _chunkStates.length,
        ));
        return;
      } on RateLimitException catch (e) {
        attempt++;
        // Сообщаем пулу о блокировке ключа на указанное время.
        _pool.reportRateLimited(key, e.retryAfterSeconds);
        _updateChunkState(index, ChunkRetrying(index, attempt: attempt));
        // Не ждём явно: следующая итерация вызовет acquireKey() и дождётся живого ключа.
      } on AuthException {
        // Неверный ключ — пробрасываем немедленно без ретрая.
        rethrow;
      } on NetworkException {
        attempt++;
        if (attempt >= maxAttempts) {
          throw const NetworkException('Превышено максимальное число попыток');
        }
        _updateChunkState(index, ChunkRetrying(index, attempt: attempt));
        // Экспоненциальная задержка: 5, 10, 20, 40... секунд (max 160 с).
        final delaySeconds = 5 * (1 << (attempt - 1).clamp(0, 5));
        await Future.delayed(Duration(seconds: delaySeconds));
      }
    }

    throw const NetworkException('Превышено максимальное число попыток');
  }

  /// Собирает финальный [TranscriptionResult] из результатов чанков.
  ///
  /// Для каждого сегмента вычисляет абсолютное время:
  /// `absoluteStart = chunkIndex * chunkDuration + segment.start`.
  /// Форматирует в `[HH:MM:SS] segment.text`.
  TranscriptionResult _assembleResult(
    List<TranscriptionResult> results,
    double chunkDuration,
  ) {
    final buffer = StringBuffer();
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
      }
    }

    return TranscriptionResult(
      text: buffer.toString().trimRight(),
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
