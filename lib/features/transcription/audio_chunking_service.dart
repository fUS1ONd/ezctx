import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/media_information.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:ezctx/core/constants/app_constants.dart';
import 'package:ezctx/core/error/app_exception.dart';
import 'audio_metadata.dart';

/// Сервис для получения метаданных аудиофайла и его разбивки на чанки.
///
/// Использует ffprobe для чтения длительности и ffmpeg для нарезки.
/// В тестах можно подменить реальные вызовы через [probeOverride] и [ffmpegOverride].
class AudioChunkingService {
  /// Переопределение ffprobe — инжектируется только в тестах.
  /// Принимает путь к файлу, возвращает [MediaInformation?] (null = нет данных).
  final Future<MediaInformation?> Function(String)? _probeOverride;

  /// Переопределение ffmpeg — инжектируется только в тестах.
  /// Принимает команду, возвращает Future<void> (бросает ошибку при неудаче).
  final Future<void> Function(String command)? _ffmpegOverride;

  const AudioChunkingService({
    Future<MediaInformation?> Function(String)? probeOverride,
    Future<void> Function(String command)? ffmpegOverride,
  })  : _probeOverride = probeOverride,
        _ffmpegOverride = ffmpegOverride;

  /// Возвращает метаданные аудиофайла по [filePath].
  ///
  /// Бросает [InternalException] если не удалось получить длительность.
  Future<AudioMetadata> getMetadata(String filePath) async {
    MediaInformation? info;

    if (_probeOverride != null) {
      // В тестах используем подменённую функцию
      info = await _probeOverride(filePath);
    } else {
      // В продакшне вызываем реальный ffprobe
      final session = await FFprobeKit.getMediaInformation(filePath);
      info = session.getMediaInformation();
    }

    final durationStr = info?.getDuration();

    if (durationStr == null) {
      throw const InternalException('Не удалось получить длительность файла');
    }

    // getDuration() возвращает строку в секундах (float), напр. "1140.233469"
    final durationSeconds = double.tryParse(durationStr);
    if (durationSeconds == null) {
      throw InternalException(
        'Не удалось разобрать длительность файла: "$durationStr"',
      );
    }
    final sizeBytes = File(filePath).statSync().size;
    final name = p.basename(filePath);

    return AudioMetadata(
      name: name,
      durationSeconds: durationSeconds,
      sizeBytes: sizeBytes,
    );
  }

  /// Разбивает аудиофайл [filePath] на равные чанки ≤ kChunkThresholdSeconds.
  ///
  /// Алгоритм: N = ceil(totalDurationSeconds / kChunkThresholdSeconds),
  /// optimalDuration = totalDurationSeconds / N.
  /// Возвращает отсортированный список файлов `chunk_NNN.ogg` во временной директории.
  /// Бросает [InternalException] при ошибке ffmpeg или если [totalDurationSeconds] ≤ 0.
  Future<List<File>> split(
    String filePath,
    double totalDurationSeconds, {
    String? outputDir,
  }) async {
    if (totalDurationSeconds <= 0) {
      throw const InternalException(
        'Длительность файла должна быть больше нуля',
      );
    }

    // Защита от command injection: отклоняем пути со спецсимволами ffmpeg/shell.
    // Проверяем до shortcircuit, чтобы инвариант работал для любой длительности.
    if (filePath.contains(RegExp(r'''["'`$\\!]'''))) {
      throw InternalException('Путь к файлу содержит недопустимые символы: $filePath');
    }

    // Shortcircuit для n=1: opus 48 kbps × 3240с ≈ 18.54 MB ≤ лимита Groq 18.5 MB (CBR-потолок).
    // Реальный VBR (~30-40 kbps) даёт ~12-16 MB. Возвращаем исходный файл без ffmpeg-сегментации,
    // чтобы -c:a copy не создавал хвостовой чанк по границе аудио-кадров.
    if (totalDurationSeconds <= AppConstants.kChunkThresholdSeconds) {
      return [File(filePath)];
    }

    // Вычисляем оптимальное число чанков и длительность каждого
    final n =
        (totalDurationSeconds / AppConstants.kChunkThresholdSeconds).ceil();
    final optimalDuration = totalDurationSeconds / n;

    // Создаём уникальную временную директорию для чанков
    final tmpBase = outputDir ??
        '${(await getTemporaryDirectory()).path}'
            '/ezctx_chunks_${DateTime.now().millisecondsSinceEpoch}';
    await Directory(tmpBase).create(recursive: true);

    // Команда ffmpeg: сегментация по времени, -c:a copy (opus-пакеты независимы — реэнкод не нужен).
    // -reset_timestamps 1 ОБЯЗАТЕЛЕН: без него segment-муксер сохраняет исходные
    // абсолютные таймстемпы Opus (granule-позиции), поэтому chunk_001 начинается
    // с отметки ~optimalDuration и сообщает длительность всей записи. Groq Whisper
    // принимает такой чанк за поток полной длины, захлёбывается и отдаёт HTTP 502
    // service_unavailable — первый чанк (0→optimalDuration) проходит, все
    // последующие ломаются. Флаг обнуляет таймстемпы каждого сегмента к нулю.
    final command =
        '-i "$filePath" -f segment -segment_time $optimalDuration'
        ' -reset_timestamps 1'
        ' -c:a copy'
        ' "$tmpBase/chunk_%03d.ogg"';

    if (_ffmpegOverride != null) {
      // В тестах override выполняет команду напрямую и бросает ошибку при неудаче
      await _ffmpegOverride(command);
    } else {
      // Оборачиваем асинхронный executeAsync в Completer
      final completer = Completer<void>();
      await FFmpegKit.executeAsync(command, (session) async {
        final rc = await session.getReturnCode();
        if (ReturnCode.isSuccess(rc)) {
          completer.complete();
        } else {
          completer.completeError(
            const InternalException('ffmpeg завершился с ошибкой'),
          );
        }
      });
      await completer.future;
    }

    // Собираем и сортируем список чанков по имени
    final chunks = Directory(tmpBase)
        .listSync()
        .whereType<File>()
        .where((f) => p.basename(f.path).startsWith('chunk_'))
        .toList()
      ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));

    return chunks;
  }
}
