import 'dart:io';

import 'package:ezctx/core/error/app_exception.dart';
import 'package:ezctx/features/transcription/audio_chunking_service.dart';
import 'package:ezctx/features/transcription/audio_normalization_service.dart';
import 'package:ffmpeg_kit_flutter_new/media_information.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ffprobe возвращает длительность в секундах (float-строка).
  MediaInformation makeInfo(String? durationSec) {
    if (durationSec == null) {
      return MediaInformation({'format': <String, dynamic>{}});
    }
    return MediaInformation({
      'format': {'duration': durationSec},
    });
  }

  group('AudioNormalizationService.normalize', () {
    test('команда содержит все обязательные флаги нормализации', () async {
      final tmpDir = Directory.systemTemp.createTempSync('ezctx_norm_test_');
      addTearDown(() => tmpDir.deleteSync(recursive: true));

      final tmpInput = File('${tmpDir.path}/input.mp3')..createSync();
      addTearDown(() { try { tmpInput.deleteSync(); } catch (_) {} });

      final tmpOutput = File('${tmpDir.path}/ezctx_norm_out.mp3')..createSync();
      addTearDown(() { try { tmpOutput.deleteSync(); } catch (_) {} });

      String? capturedCommand;
      final svc = AudioNormalizationService(
        ffmpegOverride: (cmd) async { capturedCommand = cmd; },
        chunkingService: AudioChunkingService(
          probeOverride: (_) async => makeInfo('300.0'),
        ),
        outputPathOverride: tmpOutput.path,
      );

      final result = await svc.normalize(tmpInput.path);

      expect(capturedCommand, isNotNull);
      expect(capturedCommand, contains('-b:a 32k'));
      expect(capturedCommand, contains('-ac 1'));
      expect(capturedCommand, contains('-ar 16000'));
      expect(capturedCommand, contains('-codec:a libmp3lame'));
      expect(capturedCommand, contains('-y'));
      expect(result.path, endsWith('.mp3'));
      expect(result.durationSeconds, equals(300.0));
    });

    test('входной путь присутствует в команде в кавычках', () async {
      final tmpDir = Directory.systemTemp.createTempSync('ezctx_norm_test2_');
      addTearDown(() => tmpDir.deleteSync(recursive: true));

      final tmpInput = File('${tmpDir.path}/input.mp3')..createSync();
      final tmpOutput = File('${tmpDir.path}/ezctx_norm_out.mp3')..createSync();

      String? capturedCommand;
      final svc = AudioNormalizationService(
        ffmpegOverride: (cmd) async { capturedCommand = cmd; },
        chunkingService: AudioChunkingService(
          probeOverride: (_) async => makeInfo('300.0'),
        ),
        outputPathOverride: tmpOutput.path,
      );

      await svc.normalize(tmpInput.path);

      expect(capturedCommand, contains(tmpInput.path));
      expect(capturedCommand, contains('"${tmpInput.path}"'));
    });

    test('выходной путь содержит ezctx_norm_ и оканчивается на .mp3', () async {
      final tmpDir = Directory.systemTemp.createTempSync('ezctx_norm_test3_');
      addTearDown(() => tmpDir.deleteSync(recursive: true));

      final tmpInput = File('${tmpDir.path}/input.mp3')..createSync();
      final tmpOutput = File('${tmpDir.path}/ezctx_norm_12345.mp3')..createSync();

      final svc = AudioNormalizationService(
        ffmpegOverride: (_) async {},
        chunkingService: AudioChunkingService(
          probeOverride: (_) async => makeInfo('120.0'),
        ),
        outputPathOverride: tmpOutput.path,
      );

      final result = await svc.normalize(tmpInput.path);

      expect(result.path, contains('ezctx_norm_'));
      expect(result.path, endsWith('.mp3'));
    });

    test('ошибка ffmpeg → InternalException', () async {
      final tmpDir = Directory.systemTemp.createTempSync('ezctx_norm_test4_');
      addTearDown(() => tmpDir.deleteSync(recursive: true));

      final tmpInput = File('${tmpDir.path}/input.mp3')..createSync();
      final tmpOutput = File('${tmpDir.path}/ezctx_norm_out.mp3')..createSync();

      final svc = AudioNormalizationService(
        ffmpegOverride: (_) async {
          throw const InternalException('ffmpeg error');
        },
        chunkingService: AudioChunkingService(
          probeOverride: (_) async => makeInfo('300.0'),
        ),
        outputPathOverride: tmpOutput.path,
      );

      await expectLater(
        () => svc.normalize(tmpInput.path),
        throwsA(isA<InternalException>()),
      );
    });
  });
}
