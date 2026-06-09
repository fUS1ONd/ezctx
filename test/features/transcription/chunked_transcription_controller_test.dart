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
          // Реальная длительность чанка 0 = 4500s → чанк 1 начинается с 01:15:00.
          // Кумулятивное смещение считается из r.duration (WR-06), а не из
          // усреднённого total/N, поэтому duration здесь задан явно.
          return _makeResult(
            text: 'Начало лекции',
            segments: [seg0],
            duration: 4500.0,
          );
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
    // 5b. WR-06: таймкоды считаются по реальным r.duration, без дрейфа на
    //     укороченном последнем чанке. Усреднённое total/N дало бы неверное
    //     смещение для чанков 1 и 2.
    // -----------------------------------------------------------------------
    test('таймкоды WR-06: неравные чанки не дают дрейфа смещений', () async {
      final chunks = [
        FakeChunkFile('/tmp/chunk_000.ogg'),
        FakeChunkFile('/tmp/chunk_001.ogg'),
        FakeChunkFile('/tmp/chunk_002.ogg'),
      ];

      // Реальные длительности чанков: 3000 + 3000 + 1000 = 7000s.
      // Усреднение дало бы 7000/3 ≈ 2333.3s на чанк → неверные смещения.
      // Истинные смещения: чанк0=0, чанк1=3000 (00:50:00), чанк2=6000 (01:40:00).
      final durations = [3000.0, 3000.0, 1000.0];
      int callIndex = 0;
      final apiService = MockTranscriptionProvider((_, __, ___) async {
        final i = callIndex++;
        return _makeResult(
          text: 'Чанк $i',
          // Один сегмент в начале чанка (start 0) → таймкод = смещение чанка.
          segments: [TranscriptionSegment(start: 0.0, end: 5.0, text: 'Чанк $i')],
          duration: durations[i],
        );
      });

      final chunkingService = MockAudioChunkingService(chunkFiles: chunks);

      final ctrl = ChunkedTranscriptionController(
        // durationSeconds=9000 у _dummyFile → fallback total/N=3000; но он НЕ
        // используется, т.к. r.duration > 0. Проверяем истинные смещения.
        pool: KeyPool(initialKeys: [_testKey.raw]),
        apiService: apiService,
        chunkingService: chunkingService,
      );

      await ctrl.start(_dummyFile);

      expect(ctrl.state, isA<ChunkedSuccess>());
      final text = (ctrl.state as ChunkedSuccess).result.text;

      expect(text, contains('[00:00:00]')); // чанк 0
      expect(text, contains('[00:50:00]')); // чанк 1: смещение 3000s
      expect(text, contains('[01:40:00]')); // чанк 2: смещение 6000s
      // Усреднённое смещение чанка 2 было бы 2*2333=4666s=[01:17:46] — не должно встречаться.
      expect(text, isNot(contains('[01:17:46]')));
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

  // -------------------------------------------------------------------------
  // R-06: политика конкурентности Groq — дефолтный mock без concurrencyPolicy.
  // -------------------------------------------------------------------------
  group('R-06: concurrencyFor — Groq-политика (дефолт)', () {
    test('concurrencyFor(1)==1 при дефолтной политике', () {
      final provider = MockTranscriptionProvider((_, __, ___) async => _makeResult());
      // 1 живой ключ → дефолт Groq: clamp(1, kMaxConcurrentChunks) = 1
      expect(provider.concurrencyFor(1), equals(1));
    });

    test('concurrencyFor(3)==3 при дефолтной политике', () {
      final provider = MockTranscriptionProvider((_, __, ___) async => _makeResult());
      // 3 живых ключа → дефолт Groq: clamp(3, kMaxConcurrentChunks) = 3
      expect(provider.concurrencyFor(3), equals(3));
    });
  });

  // -------------------------------------------------------------------------
  // R-07: политика конкурентности Deepgram — настраиваемая concurrencyPolicy.
  // -------------------------------------------------------------------------
  group('R-07: concurrencyFor — Deepgram-политика (настраиваемая)', () {
    test('concurrencyFor(1)==5 при Deepgram-политике (n > 0 ? 5 : 0)', () {
      final provider = MockTranscriptionProvider(
        (_, __, ___) async => _makeResult(),
        concurrencyPolicy: (n) => n > 0 ? 5 : 0,
      );
      // 1 живой ключ → Deepgram-политика: 5
      expect(provider.concurrencyFor(1), equals(5));
    });

    test('concurrencyFor(0)==0 при Deepgram-политике (n > 0 ? 5 : 0)', () {
      final provider = MockTranscriptionProvider(
        (_, __, ___) async => _makeResult(),
        concurrencyPolicy: (n) => n > 0 ? 5 : 0,
      );
      // 0 живых ключей → Deepgram-политика: 0
      expect(provider.concurrencyFor(0), equals(0));
    });

    // CR-01: concurrencyFor(0)==0, прогнанный ЧЕРЕЗ контроллер, не должен
    // приводить к вечному зависанию _Semaphore(0). Контроллер обязан
    // обнулить порог до 1 и завершиться (acquireKey сам бросит исключение,
    // если живых ключей нет). Оборачиваем в timeout — при регрессии
    // (deadlock) тест упадёт по таймауту, а не зависнет навсегда.
    test(
      'concurrencyFor(0)==0 через контроллер → завершается, не зависает',
      () async {
        final chunk = FakeChunkFile('/tmp/chunk_000.ogg');
        final apiService = MockTranscriptionProvider(
          (_, __, ___) async => _makeResult(text: 'OK'),
          // Политика, которая при любом числе ключей возвращает 0 —
          // воспроизводит Deepgram-без-живых-ключей напрямую.
          concurrencyPolicy: (_) => 0,
        );
        final chunkingService = MockAudioChunkingService(chunkFiles: [chunk]);

        final ctrl = ChunkedTranscriptionController(
          pool: KeyPool(initialKeys: [_testKey.raw]),
          apiService: apiService,
          chunkingService: chunkingService,
        );

        // start() не должен зависнуть: при флоре до 1 чанк обрабатывается.
        await ctrl.start(_dummyFile).timeout(
              const Duration(seconds: 5),
              onTimeout: () => fail(
                'start() завис при concurrencyFor(0)==0 — _Semaphore(0) deadlock',
              ),
            );

        // Живой ключ есть → чанк успешно обработан, без зависания.
        expect(ctrl.state, isA<ChunkedSuccess>());
      },
    );

    // CR-01 (продолжение): concurrency 0 И нет живых ключей → контроллер
    // должен завершиться ошибкой (ChunkedError), а не зависнуть.
    test(
      'concurrencyFor(0)==0 без живых ключей → ChunkedError, не зависает',
      () async {
        final chunk = FakeChunkFile('/tmp/chunk_000.ogg');
        final apiService = MockTranscriptionProvider(
          (_, __, ___) async => _makeResult(),
          concurrencyPolicy: (_) => 0,
        );
        final chunkingService = MockAudioChunkingService(chunkFiles: [chunk]);

        // Пул с ключом, который сразу исчерпан → aliveKeyCount==0,
        // _blockedUntil пуст → acquireKey бросит AllKeysBlockedException.
        final pool = KeyPool(initialKeys: ['only-key-test']);
        pool.reportExhausted('only-key-test');

        final ctrl = ChunkedTranscriptionController(
          pool: pool,
          apiService: apiService,
          chunkingService: chunkingService,
        );

        await ctrl.start(_dummyFile).timeout(
              const Duration(seconds: 5),
              onTimeout: () => fail(
                'start() завис вместо немедленной ошибки при отсутствии ключей',
              ),
            );

        expect(ctrl.state, isA<ChunkedError>());
      },
    );
  });

  // -------------------------------------------------------------------------
  // R-08: KeyExhaustedException → reportExhausted без инкремента счётчиков.
  // -------------------------------------------------------------------------
  group('R-08: KeyExhaustedException → reportExhausted', () {
    test(
      'первый ключ исчерпан → reportExhausted, второй ключ успешен, state==ChunkedSuccess',
      () async {
        final chunk = FakeChunkFile('/tmp/chunk_000.ogg');
        int callCount = 0;
        // Первый вызов: бросает KeyExhaustedException (ключ k1).
        // Второй вызов: успех (ключ k2).
        final apiService = MockTranscriptionProvider((_, __, String apiKey) async {
          callCount++;
          if (callCount == 1) {
            throw const KeyExhaustedException();
          }
          return _makeResult(text: 'Успех со вторым ключом');
        });
        final chunkingService = MockAudioChunkingService(chunkFiles: [chunk]);

        // Пул из 2 ключей — первый будет exhausted, второй используется.
        final pool = KeyPool(initialKeys: ['key1-test', 'key2-test']);

        final ctrl = ChunkedTranscriptionController(
          pool: pool,
          apiService: apiService,
          chunkingService: chunkingService,
        );

        await ctrl.start(_dummyFile);

        // Итог — успешная транскрибация со вторым ключом.
        expect(
          ctrl.state,
          isA<ChunkedSuccess>(),
          reason: 'После exhausted-ключа контроллер должен использовать второй ключ',
        );

        // Первый ключ должен быть exhausted — aliveKeyCount уменьшился.
        expect(
          pool.aliveKeyCount,
          equals(1),
          reason: 'После reportExhausted(key1) должен остаться 1 живой ключ',
        );

        // Также проверяем через статусы: первый ключ — ExhaustedKeyStatus.
        final statuses = pool.getStatuses();
        expect(
          statuses.any((s) => s is ExhaustedKeyStatus),
          isTrue,
          reason: 'Один из ключей должен иметь статус ExhaustedKeyStatus',
        );

        // mock вызван дважды: первый раз KeyExhaustedException, второй — успех.
        expect(
          callCount,
          equals(2),
          reason: 'transcribeChunk должен быть вызван 2 раза (1 exhausted + 1 успех)',
        );
      },
    );
  });
}
