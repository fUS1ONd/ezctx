import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/media_information.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:ezctx/core/error/app_exception.dart';
import 'audio_metadata.dart';

/// Длительность одного чанка в секундах (1200s = 20 мин, ~19 МБ при 128k).
const double kChunkDurationSeconds = 1200.0;

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

  /// Разбивает аудиофайл [filePath] на чанки ≤ 19 МБ.
  ///
  /// Возвращает отсортированный список файлов `chunk_NNN.mp3` во временной директории.
  /// Бросает [InternalException] при ошибке ffmpeg.
  Future<List<File>> split(String filePath, {String? outputDir}) async {
    // Создаём уникальную временную директорию для чанков
    final tmpBase = outputDir ??
        '${(await getTemporaryDirectory()).path}'
            '/ezctx_chunks_${DateTime.now().millisecondsSinceEpoch}';
    await Directory(tmpBase).create(recursive: true);

    // Команда ffmpeg: сегментация по времени, mp3 128k mono 16kHz
    final command =
        '-i "$filePath" -f segment -segment_time ${kChunkDurationSeconds.toInt()}'
        ' -c:a libmp3lame -b:a 128k -ac 1 -ar 16000'
        ' "$tmpBase/chunk_%03d.mp3"';

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
