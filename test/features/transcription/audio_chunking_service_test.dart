import 'dart:io';

import 'package:ezctx/core/error/app_exception.dart';
import 'package:ezctx/features/transcription/audio_chunking_service.dart';
import 'package:ffmpeg_kit_flutter_new/media_information.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ffprobe возвращает длительность в СЕКУНДАХ (float-строка), не в мс.
  MediaInformation makeInfo(String? durationSec) {
    if (durationSec == null) {
      return MediaInformation({'format': <String, dynamic>{}});
    }
    return MediaInformation({
      'format': {'duration': durationSec},
    });
  }

  group('AudioChunkingService.getMetadata — длительность в секундах', () {
    test('успех: "5.0" с → durationSeconds == 5.0', () async {
      final service = AudioChunkingService(
        probeOverride: (_) async => makeInfo('5.0'),
      );
      final tmp = await File('${Directory.systemTemp.path}/test_5s.mp3').create();
      addTearDown(() => tmp.deleteSync());

      final meta = await service.getMetadata(tmp.path);
      expect(meta.durationSeconds, equals(5.0));
    });

    test('19-минутный файл: "1140.23" → durationSeconds == 1140.23', () async {
      // Регрессия: старый код делил на 1000 → 1.14 с вместо 19 мин.
      final service = AudioChunkingService(
        probeOverride: (_) async => makeInfo('1140.23'),
      );
      final tmp = await File('${Directory.systemTemp.path}/test_19m.mp3').create();
      addTearDown(() => tmp.deleteSync());

      final meta = await service.getMetadata(tmp.path);
      expect(meta.durationSeconds, closeTo(1140.23, 0.001));
      expect(meta.durationFormatted, equals('19:00'));
    });

    test('65-минутный файл: "3932.0" → durationSeconds == 3932', () async {
      final service = AudioChunkingService(
        probeOverride: (_) async => makeInfo('3932.0'),
      );
      final tmp = await File('${Directory.systemTemp.path}/test_65m.mp3').create();
      addTearDown(() => tmp.deleteSync());

      final meta = await service.getMetadata(tmp.path);
      expect(meta.durationSeconds, closeTo(3932.0, 0.001));
      expect(meta.durationFormatted, equals('1:05:32'));
    });

    test('null duration → InternalException', () async {
      final service = AudioChunkingService(
        probeOverride: (_) async => makeInfo(null),
      );
      final tmp = await File('${Directory.systemTemp.path}/test_null.mp3').create();
      addTearDown(() => tmp.deleteSync());

      await expectLater(
        () => service.getMetadata(tmp.path),
        throwsA(isA<InternalException>()),
      );
    });

    test('непарсируемая строка "abc" → InternalException', () async {
      final service = AudioChunkingService(
        probeOverride: (_) async => makeInfo('abc'),
      );
      final tmp = await File('${Directory.systemTemp.path}/test_abc.mp3').create();
      addTearDown(() => tmp.deleteSync());

      await expectLater(
        () => service.getMetadata(tmp.path),
        throwsA(isA<InternalException>()),
      );
    });
  });

  group('AudioChunkingService.split — количество чанков', () {
    Future<Directory> _tmpDir() async {
      final d = Directory(
        '${Directory.systemTemp.path}/ezctx_test_${DateTime.now().millisecondsSinceEpoch}',
      );
      await d.create(recursive: true);
      return d;
    }

    test('2 чанка создаются и возвращаются в порядке', () async {
      final outDir = await _tmpDir();
      addTearDown(() => outDir.deleteSync(recursive: true));

      await File('${outDir.path}/chunk_000.mp3').create();
      await File('${outDir.path}/chunk_001.mp3').create();

      final service = AudioChunkingService(ffmpegOverride: (_) async {});
      final chunks = await service.split('/fake/input.mp3', outputDir: outDir.path);

      expect(chunks.length, equals(2));
      expect(chunks[0].path, endsWith('chunk_000.mp3'));
      expect(chunks[1].path, endsWith('chunk_001.mp3'));
    });

    test('4 чанка (часовое аудио)', () async {
      final outDir = await _tmpDir();
      addTearDown(() => outDir.deleteSync(recursive: true));

      for (var i = 0; i < 4; i++) {
        await File('${outDir.path}/chunk_00$i.mp3').create();
      }

      final service = AudioChunkingService(ffmpegOverride: (_) async {});
      final chunks = await service.split('/fake/long.mp3', outputDir: outDir.path);

      expect(chunks.length, equals(4));
    });

    test('1 чанк (файл < kChunkDurationSeconds по длительности)', () async {
      final outDir = await _tmpDir();
      addTearDown(() => outDir.deleteSync(recursive: true));

      await File('${outDir.path}/chunk_000.mp3').create();

      final service = AudioChunkingService(ffmpegOverride: (_) async {});
      final chunks = await service.split('/fake/short.mp3', outputDir: outDir.path);

      expect(chunks.length, equals(1));
    });

    test('ffmpeg-команда содержит правильные параметры кодирования', () async {
      final outDir = await _tmpDir();
      addTearDown(() => outDir.deleteSync(recursive: true));

      String? capturedCommand;
      final service = AudioChunkingService(
        ffmpegOverride: (cmd) async { capturedCommand = cmd; },
      );

      await service.split('/input/audio.mp3', outputDir: outDir.path);

      expect(capturedCommand, isNotNull);
      expect(capturedCommand, contains('-f segment'));
      expect(capturedCommand, contains('-segment_time 1200'));
      expect(capturedCommand, contains('-c:a libmp3lame'));
      expect(capturedCommand, contains('-b:a 128k'));
      expect(capturedCommand, contains('-ac 1'));
      expect(capturedCommand, contains('-ar 16000'));
      expect(capturedCommand, contains('chunk_%03d.mp3'));
    });

    test('ошибка ffmpeg → InternalException', () async {
      final outDir = await _tmpDir();
      addTearDown(() => outDir.deleteSync(recursive: true));

      final service = AudioChunkingService(
        ffmpegOverride: (_) async {
          throw const InternalException('ffmpeg завершился с ошибкой');
        },
      );

      await expectLater(
        () => service.split('/fake/input.mp3', outputDir: outDir.path),
        throwsA(isA<InternalException>()),
      );
    });
  });
}
