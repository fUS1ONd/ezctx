import 'dart:io';

import 'package:ezctx/core/error/app_exception.dart';
import 'package:ezctx/features/transcription/audio_chunking_service.dart';
import 'package:ffmpeg_kit_flutter_new/media_information.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Вспомогательная функция: создаёт MediaInformation с заданной длительностью (мс).
  MediaInformation makeInfo(String? durationMs) {
    if (durationMs == null) {
      return MediaInformation({'format': <String, dynamic>{}});
    }
    return MediaInformation({
      'format': {'duration': durationMs},
    });
  }

  group('AudioChunkingService.getMetadata', () {
    test('успех: duration "5000" мс → durationSeconds == 5.0', () async {
      final service = AudioChunkingService(
        probeOverride: (_) async => makeInfo('5000'),
      );

      // Используем несуществующий файл — size считается через statSync,
      // поэтому создадим временный файл.
      final tmp = await File('${Directory.systemTemp.path}/test_audio.mp3')
          .create();
      addTearDown(() => tmp.delete());

      final meta = await service.getMetadata(tmp.path);

      expect(meta.durationSeconds, equals(5.0));
      expect(meta.name, equals('test_audio.mp3'));
    });

    test('null duration → InternalException', () async {
      final service = AudioChunkingService(
        probeOverride: (_) async => makeInfo(null),
      );

      final tmp = await File('${Directory.systemTemp.path}/test_null.mp3')
          .create();
      addTearDown(() => tmp.delete());

      expect(
        () => service.getMetadata(tmp.path),
        throwsA(isA<InternalException>()),
      );
    });

    test('непарсируемая строка "abc" → InternalException', () async {
      final service = AudioChunkingService(
        probeOverride: (_) async => makeInfo('abc'),
      );

      final tmp = await File('${Directory.systemTemp.path}/test_abc.mp3')
          .create();
      addTearDown(() => tmp.delete());

      expect(
        () => service.getMetadata(tmp.path),
        throwsA(isA<InternalException>()),
      );
    });
  });

  group('AudioChunkingService.split', () {
    test('успех: ffmpeg override завершается без ошибки', () async {
      // Создаём временную выходную директорию
      final outDir = Directory(
        '${Directory.systemTemp.path}/ezctx_test_chunks_${DateTime.now().millisecondsSinceEpoch}',
      );
      await outDir.create(recursive: true);
      addTearDown(() => outDir.deleteSync(recursive: true));

      // Создаём фиктивные chunk-файлы, которые сервис соберёт после "ffmpeg"
      await File('${outDir.path}/chunk_000.mp3').create();
      await File('${outDir.path}/chunk_001.mp3').create();

      final service = AudioChunkingService(
        ffmpegOverride: (_) async {
          // Успешный ffmpeg — ничего не бросаем
        },
      );

      final chunks = await service.split(
        '/fake/input.mp3',
        outputDir: outDir.path,
      );

      expect(chunks.length, equals(2));
      expect(chunks[0].path, endsWith('chunk_000.mp3'));
      expect(chunks[1].path, endsWith('chunk_001.mp3'));
    });

    test('ошибка ffmpeg: override бросает InternalException', () async {
      final outDir = Directory(
        '${Directory.systemTemp.path}/ezctx_test_err_${DateTime.now().millisecondsSinceEpoch}',
      );
      await outDir.create(recursive: true);
      addTearDown(() => outDir.deleteSync(recursive: true));

      final service = AudioChunkingService(
        ffmpegOverride: (_) async {
          throw const InternalException('ffmpeg завершился с ошибкой');
        },
      );

      expect(
        () => service.split('/fake/input.mp3', outputDir: outDir.path),
        throwsA(isA<InternalException>()),
      );
    });
  });
}
