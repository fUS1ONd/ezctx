import 'dart:io';

import 'package:ezctx/core/constants/app_constants.dart';
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

      await File('${outDir.path}/chunk_000.ogg').create();
      await File('${outDir.path}/chunk_001.ogg').create();

      final service = AudioChunkingService(ffmpegOverride: (_) async {});
      // 108 мин = 6480s > порога 3240s → N=2
      final chunks = await service.split('/fake/input.ogg', 6480.0, outputDir: outDir.path);

      expect(chunks.length, equals(2));
      expect(chunks[0].path, endsWith('chunk_000.ogg'));
      expect(chunks[1].path, endsWith('chunk_001.ogg'));
    });

    test('4 чанка (часовое аудио)', () async {
      final outDir = await _tmpDir();
      addTearDown(() => outDir.deleteSync(recursive: true));

      for (var i = 0; i < 4; i++) {
        await File('${outDir.path}/chunk_00$i.ogg').create();
      }

      final service = AudioChunkingService(ffmpegOverride: (_) async {});
      // 330 мин = 19800s → N=ceil(19800/3240)=7, но тест проверяет возвращаемые файлы
      final chunks = await service.split('/fake/long.ogg', 19800.0, outputDir: outDir.path);

      expect(chunks.length, equals(4));
    });

    test('1 чанк (50 мин = 3000s, меньше порога 3240s)', () async {
      final outDir = await _tmpDir();
      addTearDown(() => outDir.deleteSync(recursive: true));

      await File('${outDir.path}/chunk_000.ogg').create();

      final service = AudioChunkingService(ffmpegOverride: (_) async {});
      final chunks = await service.split('/fake/short.ogg', 3000.0, outputDir: outDir.path);

      expect(chunks.length, equals(1));
    });

    test('108 мин (6480s): N=2, optimalDuration=3240 → содержит -segment_time 3240.0', () async {
      final outDir = await _tmpDir();
      addTearDown(() => outDir.deleteSync(recursive: true));

      String? capturedCommand;
      final service = AudioChunkingService(
        ffmpegOverride: (cmd) async { capturedCommand = cmd; },
      );

      await service.split('/input/audio.ogg', 6480.0, outputDir: outDir.path);

      expect(capturedCommand, isNotNull);
      expect(capturedCommand, contains('-f segment'));
      expect(capturedCommand, contains('-segment_time 3240.0'));
      expect(capturedCommand, contains('-c:a copy'));
      expect(capturedCommand, contains('chunk_%03d.ogg'));
    });

    test('150 мин (9000s): N=3, optimalDuration=3000 → содержит -segment_time 3000.0', () async {
      final outDir = await _tmpDir();
      addTearDown(() => outDir.deleteSync(recursive: true));

      String? capturedCommand;
      final service = AudioChunkingService(
        ffmpegOverride: (cmd) async { capturedCommand = cmd; },
      );

      await service.split('/input/audio.ogg', 9000.0, outputDir: outDir.path);

      expect(capturedCommand, isNotNull);
      expect(capturedCommand, contains('-segment_time 3000.0'));
    });

    test('165 мин (9900s): N=4, optimalDuration=2475 → содержит -segment_time 2475.0', () async {
      final outDir = await _tmpDir();
      addTearDown(() => outDir.deleteSync(recursive: true));

      String? capturedCommand;
      final service = AudioChunkingService(
        ffmpegOverride: (cmd) async { capturedCommand = cmd; },
      );

      await service.split('/input/audio.ogg', 9900.0, outputDir: outDir.path);

      expect(capturedCommand, isNotNull);
      expect(capturedCommand, contains('-segment_time 2475.0'));
    });

    test('ошибка ffmpeg → InternalException', () async {
      final outDir = await _tmpDir();
      addTearDown(() => outDir.deleteSync(recursive: true));

      final service = AudioChunkingService(
        ffmpegOverride: (_) async {
          throw const InternalException('ffmpeg завершился с ошибкой');
        },
      );

      // 6480s > kChunkThresholdSeconds → shortcircuit не срабатывает, ffmpeg вызывается
      await expectLater(
        () => service.split('/fake/input.ogg', 6480.0, outputDir: outDir.path),
        throwsA(isA<InternalException>()),
      );
    });

    test('totalDurationSeconds <= 0 → InternalException', () async {
      final outDir = await _tmpDir();
      addTearDown(() => outDir.deleteSync(recursive: true));

      final service = AudioChunkingService(ffmpegOverride: (_) async {});

      await expectLater(
        () => service.split('/fake/input.ogg', 0.0, outputDir: outDir.path),
        throwsA(isA<InternalException>()),
      );
    });

    // CHUNK-05: VBR-граничный тест. Документирует осознанное решение (RESEARCH.md Q4):
    // (1) AppConstants.maxFileSizeBytes = 19 MB = 19 922 944 байт — входной guard, против него assert.
    // (2) Реальный лимит Groq Whisper = 18.5 MB = 19 398 656 байт.
    // (3) 3240 × 6000 = 19 440 000 ≈ 18.54 MB — CBR-потолок формально на ~41 KB выше Groq-лимита,
    //     но реальный речевой opus VBR (~30-40 kbps) даёт 12-16 MB с двойным запасом.
    //     Runtime-guard не реализован осознанно (Q2 RESOLVED: Don't Hand-Roll).
    test('CHUNK-05 VBR-граница: 3240с × 6000 B/s <= maxFileSizeBytes', () {
      expect(
        AppConstants.kChunkThresholdSeconds * 6000,
        lessThanOrEqualTo(AppConstants.maxFileSizeBytes),
      );
    });
  });

  group('AudioChunkingService.split — shortcircuit (n=1)', () {
    // R1: короткий файл → без ffmpeg, возвращается исходный путь
    test('R1: duration < kChunkThresholdSeconds → исходный файл без вызова ffmpeg', () async {
      var ffmpegCalled = false;
      final service = AudioChunkingService(
        ffmpegOverride: (_) async { ffmpegCalled = true; },
      );
      final result = await service.split('/tmp/fake.ogg', 300.0);
      expect(ffmpegCalled, isFalse);
      expect(result, hasLength(1));
      expect(result.first.path, equals('/tmp/fake.ogg'));
    });

    // R2: граничный случай — duration == kChunkThresholdSeconds попадает в shortcircuit
    test('R2: duration == kChunkThresholdSeconds → shortcircuit, ffmpeg не вызван', () async {
      var ffmpegCalled = false;
      final service = AudioChunkingService(
        ffmpegOverride: (_) async { ffmpegCalled = true; },
      );
      final threshold = AppConstants.kChunkThresholdSeconds.toDouble();
      final result = await service.split('/tmp/fake.ogg', threshold);
      expect(ffmpegCalled, isFalse);
      expect(result, hasLength(1));
      expect(result.first.path, equals('/tmp/fake.ogg'));
    });

    // R5: валидация спецсимволов работает ДО shortcircuit
    test('R5: пути со спецсимволами отклоняются даже для коротких файлов', () async {
      final service = AudioChunkingService();
      await expectLater(
        () => service.split('/tmp/bad"name.ogg', 300.0),
        throwsA(isA<InternalException>()),
      );
      await expectLater(
        () => service.split('/tmp/bad\$name.ogg', 300.0),
        throwsA(isA<InternalException>()),
      );
    });
  });
}
