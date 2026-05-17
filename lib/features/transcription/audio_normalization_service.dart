import 'dart:async';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';

import 'package:ezctx/core/error/app_exception.dart';
import 'audio_chunking_service.dart';
import 'normalized_audio_file.dart';

/// Сервис нормализации аудио: конвертирует входной файл в mp3 32k/16kHz/Mono
/// через ffmpeg для последующего чанкования и отправки в Groq Whisper API.
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

  /// Нормализует аудиофайл [inputPath] в mp3 32k/16kHz/Mono во временную директорию.
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
      outPath = '$tmpDir/ezctx_norm_${DateTime.now().millisecondsSinceEpoch}.mp3';
    }

    // Конвертация в mp3 32k/16kHz/Mono: оптимальный баланс качества и размера для ASR
    final command =
        '-i "$inputPath" -b:a 32k -ac 1 -ar 16000 -codec:a libmp3lame -y "$outPath"';

    if (_ffmpegOverride != null) {
      await _ffmpegOverride!(command);
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
