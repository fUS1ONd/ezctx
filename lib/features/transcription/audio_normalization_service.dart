import 'dart:async';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';

import 'package:ezctx/core/error/app_exception.dart';
import 'audio_chunking_service.dart';
import 'normalized_audio_file.dart';

/// Сервис нормализации аудио: конвертирует входной файл в opus 48k/16kHz/Mono (.ogg)
/// через ffmpeg для последующего чанкования и отправки в Groq Whisper API.
/// libopus доступен в Full-GPL сборке ffmpeg_kit_flutter_new 4.1.0 — fallback на mp3 не нужен.
class AudioNormalizationService {
  /// Переопределение ffmpeg — инжектируется только в тестах.
  final Future<void> Function(String command)? _ffmpegOverride;

  /// Сервис получения метаданных — нужен для чтения длительности нормализованного файла.
  final AudioChunkingService _chunkingService;

  /// Переопределение выходного пути — инжектируется только в тестах.
  final String? _outputPathOverride;

  const AudioNormalizationService({
    Future<void> Function(String command)? ffmpegOverride,
    AudioChunkingService? chunkingService,
    String? outputPathOverride,
  })  : _ffmpegOverride = ffmpegOverride,
        _chunkingService = chunkingService ?? const AudioChunkingService(),
        _outputPathOverride = outputPathOverride;

  /// Нормализует аудиофайл [inputPath] в opus 48k/16kHz/Mono (.ogg) во временную директорию.
  ///
  /// Возвращает [NormalizedAudioFile] с путём и длительностью нормализованного файла.
  /// Бросает [InternalException] при ошибке ffmpeg.
  Future<NormalizedAudioFile> normalize(String inputPath) async {
    final String outPath;
    if (_outputPathOverride != null) {
      // В тестах используем переданный путь вместо getTemporaryDirectory
      outPath = _outputPathOverride;
    } else {
      final tmpDir = (await getTemporaryDirectory()).path;
      outPath = '$tmpDir/ezctx_norm_${DateTime.now().millisecondsSinceEpoch}.ogg';
    }

    // Конвертация в opus 48k/16kHz/Mono: улучшенное качество ASR (CER ~5% vs ~12.35% mp3 32k).
    // -vn: defensive отбрасывание видеодорожки (вход может быть mp4/webm).
    // libopus доступен в Full-GPL сборке ffmpeg_kit_flutter_new 4.1.0, fallback не нужен.
    final command =
        '-i "$inputPath" -vn -c:a libopus -b:a 48k -ac 1 -ar 16000 -y "$outPath"';

    final ffmpegOverride = _ffmpegOverride;
    if (ffmpegOverride != null) {
      await ffmpegOverride(command);
    } else {
      // Оборачиваем асинхронный executeAsync в Completer
      final completer = Completer<void>();
      await FFmpegKit.executeAsync(command, (session) async {
        final rc = await session.getReturnCode();
        if (ReturnCode.isSuccess(rc)) {
          completer.complete();
        } else {
          completer.completeError(
            const InternalException('ffmpeg: нормализация завершилась с ошибкой'),
          );
        }
      });
      await completer.future;
    }

    // Читаем длительность нормализованного файла через ffprobe
    final meta = await _chunkingService.getMetadata(outPath);
    return NormalizedAudioFile(path: outPath, durationSeconds: meta.durationSeconds);
  }
}
