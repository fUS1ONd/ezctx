import 'package:ezctx/core/error/app_exception.dart';
import 'package:ezctx/features/settings/api_key_repository.dart';
import 'package:ezctx/features/transcription/audio_metadata.dart';
import 'package:ezctx/features/transcription/chunked_transcription_controller.dart';
import 'package:ezctx/features/transcription/key_pool.dart';
import 'package:ezctx/features/transcription/normalized_audio_file.dart';
import 'package:ezctx/features/transcription/transcription_result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/transcription_mocks.dart';

// ---------------------------------------------------------------------------
// Константы.
// ---------------------------------------------------------------------------

const _testKey = ApiKeyView(
  raw: 'test-api-key-1234567890',
  masked: '••••••••••••••••1234',
);

final _dummyFile = NormalizedAudioFile(
  path: '/tmp/test_lecture.ogg',
  // 9000s = 2.5 ч → chunkDuration = 9000/2 = 4500s → offset чанка 1 = [01:15:00]
  durationSeconds: 9000.0,
);

TranscriptionResult _makeResult({
  String text = 'Привет мир',
  List<TranscriptionSegment> segments = const [],
  double duration = 60.0,
}) =>
    TranscriptionResult(
      text: text,
      language: 'ru',
      duration: duration,
      words: const [],
      segments: segments,
    );

// ---------------------------------------------------------------------------
// Тесты.
// ---------------------------------------------------------------------------

void main() {
  group('ChunkedTranscriptionController', () {
    // -----------------------------------------------------------------------
    // 1. Успешная транскрибация одного чанка.
    // -----------------------------------------------------------------------
    test('успех: один чанк → ChunkedSuccess с текстом', () async {
      final chunk = FakeChunkFile('/tmp/chunk_000.ogg');
      final apiService = MockTranscriptionProvider(
        (_, __, ___) async => _makeResult(text: 'Лекция по физике'),
      );
      final chunkingService = MockAudioChunkingService(chunkFiles: [chunk]);

      final ctrl = ChunkedTranscriptionController(
        pool: KeyPool(initialKeys: [_testKey.raw]),
        apiService: apiService,
        chunkingService: chunkingService,
      );

      await ctrl.start(_dummyFile);

      expect(ctrl.state, isA<ChunkedSuccess>());
      final success = ctrl.state as ChunkedSuccess;
      expect(success.result.text, contains('Лекция по физике'));
    });

    // -----------------------------------------------------------------------
    // 2. Retry на NetworkException → итог ChunkedSuccess.
    // -----------------------------------------------------------------------
    test('retry: NetworkException на первом вызове → второй вызов успешен', () async {
      final chunk = FakeChunkFile('/tmp/chunk_000.ogg');
      int calls = 0;
      final apiService = MockTranscriptionProvider((_, __, ___) async {
        calls++;
        if (calls == 1) throw const NetworkException('timeout');
        return _makeResult(text: 'Успех после retry');
      });
      final chunkingService = MockAudioChunkingService(chunkFiles: [chunk]);

      final ctrl = ChunkedTranscriptionController(
        pool: KeyPool(initialKeys: [_testKey.raw]),
        apiService: apiService,
        chunkingService: chunkingService,
        retryDelay: (_) => Duration.zero,
      );

      await ctrl.start(_dummyFile);

      expect(ctrl.state, isA<ChunkedSuccess>());
      expect(calls, equals(2));
    });

    // -----------------------------------------------------------------------
    // 3. AuthException — не ретраится.
    // -----------------------------------------------------------------------
    test('нет retry на AuthException: mock вызван ровно 1 раз', () async {
      final chunk = FakeChunkFile('/tmp/chunk_000.ogg');
      final apiService = MockTranscriptionProvider(
        (_, __, ___) async => throw const AuthException('Неверный ключ'),
      );
      final chunkingService = MockAudioChunkingService(chunkFiles: [chunk]);

      final ctrl = ChunkedTranscriptionController(
        pool: KeyPool(initialKeys: [_testKey.raw]),
        apiService: apiService,
        chunkingService: chunkingService,
      );

      await ctrl.start(_dummyFile);

      expect(ctrl.state, isA<ChunkedError>());
      final err = ctrl.state as ChunkedError;
      expect(err.retryable, isFalse);
      expect(apiService.callCount, equals(1));
    });

    // -----------------------------------------------------------------------
    // 4. Параллельность ≤ maxConcurrent.
    // -----------------------------------------------------------------------
    test('параллельность: не более maxConcurrent=2 одновременных запросов', () async {
      const maxConcurrent = 2;
      const totalChunks = 5;

      int concurrent = 0;
      int maxObservedConcurrent = 0;

      final chunks = List.generate(
        totalChunks,
        (i) => FakeChunkFile('/tmp/chunk_${i.toString().padLeft(3, '0')}.ogg'),
      );

      final apiService = MockTranscriptionProvider((_, __, ___) async {
        concurrent++;
        if (concurrent > maxObservedConcurrent) {
          maxObservedConcurrent = concurrent;
        }
        await Future.delayed(const Duration(milliseconds: 30));
        concurrent--;
        return _makeResult();
      });
      final chunkingService = MockAudioChunkingService(chunkFiles: chunks);

      // 2 ключа → aliveKeyCount=2 → semaphore=min(2, kMaxConcurrentChunks)=2
      final ctrl = ChunkedTranscriptionController(
        pool: KeyPool(initialKeys: [_testKey.raw, 'second-key-${_testKey.raw}']),
        apiService: apiService,
        chunkingService: chunkingService,
      );

      await ctrl.start(_dummyFile);

      expect(
        maxObservedConcurrent,
        lessThanOrEqualTo(maxConcurrent),
        reason:
            'Одновременно работало $maxObservedConcurrent, максимум должен быть ≤ $maxConcurrent',
      );
      expect(ctrl.state, isA<ChunkedSuccess>());
    });

    // -----------------------------------------------------------------------
    // 5. Сборка таймкодов.
    // -----------------------------------------------------------------------
    test('таймкоды: chunk 0 → [00:00:00], chunk 1 offset 4500s → [01:15:00]', () async {
      final chunks = [
        FakeChunkFile('/tmp/chunk_000.ogg'),
        FakeChunkFile('/tmp/chunk_001.ogg'),
      ];

      final seg0 = TranscriptionSegment(
        start: 0.0,
        end: 5.0,
        text: 'Начало лекции',
      );
      final seg1 = TranscriptionSegment(
        start: 0.0,
        end: 5.0,
        text: 'Продолжение',
      );
      final seg1b = TranscriptionSegment(
        start: 5.0,
        end: 10.0,
        text: 'Ещё кусок',
      );

      int callIndex = 0;
      final apiService = MockTranscriptionProvider((_, __, ___) async {
        final i = callIndex++;
        if (i == 0) {
          return _makeResult(text: 'Начало лекции', segments: [seg0]);
        }
        return _makeResult(text: 'Продолжение', segments: [seg1, seg1b]);
      });

      final chunkingService = MockAudioChunkingService(
        chunkFiles: chunks,
        metadata: const AudioMetadata(
          name: 'test.ogg',
          durationSeconds: 2400.0,
          sizeBytes: 1024,
        ),
      );

      final ctrl = ChunkedTranscriptionController(
        pool: KeyPool(initialKeys: [_testKey.raw]),
        apiService: apiService,
        chunkingService: chunkingService,
      );

      await ctrl.start(_dummyFile);

      expect(ctrl.state, isA<ChunkedSuccess>());
      final text = (ctrl.state as ChunkedSuccess).result.text;

      expect(text, contains('[00:00:00]'));
      expect(text, contains('[01:15:00]'));
      expect(text, contains('[01:15:05]'));
    });

    // -----------------------------------------------------------------------
    // 6. Cleanup: tmp-чанки удаляются.
    // -----------------------------------------------------------------------
    test('cleanup: все tmp-чанки удалены после старта (success)', () async {
      final chunks = List.generate(
        3,
        (i) => FakeChunkFile('/tmp/chunk_$i.ogg'),
      );

      final apiService = MockTranscriptionProvider(
        (_, __, ___) async => _makeResult(),
      );
      final chunkingService = MockAudioChunkingService(chunkFiles: chunks);

      final ctrl = ChunkedTranscriptionController(
        pool: KeyPool(initialKeys: [_testKey.raw]),
        apiService: apiService,
        chunkingService: chunkingService,
      );

      await ctrl.start(_dummyFile);

      for (final f in chunks) {
        expect(
          f.deleted,
          isTrue,
          reason: 'Файл ${f.path} должен быть удалён',
        );
      }
    });

    // -----------------------------------------------------------------------
    // Дополнительно: ChunkedMissingKey.
    // -----------------------------------------------------------------------
    test('отсутствие ключа → ChunkedMissingKey', () async {
      final apiService = MockTranscriptionProvider(
        (_, __, ___) async => _makeResult(),
      );
      final chunkingService = MockAudioChunkingService(chunkFiles: []);

      final ctrl = ChunkedTranscriptionController(
        pool: KeyPool(),
        apiService: apiService,
        chunkingService: chunkingService,
      );

      await ctrl.start(_dummyFile);

      expect(ctrl.state, isA<ChunkedMissingKey>());
    });
  });
}
