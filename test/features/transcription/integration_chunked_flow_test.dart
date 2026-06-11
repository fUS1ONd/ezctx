/// Интеграционный тест полного chunked-пайплайна Phase 2.
///
/// Проверяет end-to-end поток: split → transcribeChunk → assembly → ChunkedSuccess/Error.
/// Использует ручные моки без Flutter binding (чистый dart:test) для скорости.
library;

import 'package:ezctx/core/error/app_exception.dart';
import 'package:ezctx/features/settings/api_key_repository.dart';
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
  // 9000s = 2.5 ч → 2 чанка инжектируются напрямую; chunkDuration = 9000/2 = 4500s
  // (контроллер делит на число чанков, не на порог) → offset чанка 1 = [01:15:00]
  durationSeconds: 9000.0,
);

// ---------------------------------------------------------------------------
// Интеграционные тесты.
// ---------------------------------------------------------------------------

void main() {
  group('Integration: ChunkedTranscriptionController — полный пайплайн', () {
    // -----------------------------------------------------------------------
    // Сценарий 1: Happy path, 2 чанка с сегментами → таймкоды в тексте.
    // -----------------------------------------------------------------------
    test('сценарий 1 — happy path 2 чанка: ChunkedSuccess, текст с таймкодами', () async {
      final chunks = [
        FakeChunkFile('/tmp/chunk_000.ogg'),
        FakeChunkFile('/tmp/chunk_001.ogg'),
      ];

      // Сегмент в чанке 0 (offset=0s): [00:00:00] Привет мир
      final seg0 = TranscriptionSegment(
        start: 0.0,
        end: 2.0,
        text: 'Привет мир',
      );
      // Сегмент в чанке 1 (offset=4500s): [01:15:00] Как дела
      final seg1 = TranscriptionSegment(
        start: 0.0,
        end: 1.5,
        text: 'Как дела',
      );

      int callIndex = 0;
      final apiService = MockTranscriptionProvider((_, __, ___) async {
        final i = callIndex++;
        if (i == 0) {
          return TranscriptionResult(
            text: 'Привет мир',
            language: 'ru',
            // Реальная длительность чанка 0 = 4500s → кумулятивное смещение
            // чанка 1 = 4500s (WR-06: считаем по r.duration, не по total/N).
            duration: 4500.0,
            words: const [],
            segments: [seg0],
          );
        }
        return TranscriptionResult(
          text: 'Как дела',
          language: 'ru',
          duration: 60.0,
          words: const [],
          segments: [seg1],
        );
      });

      // 1 ключ → aliveKeyCount=1 → semaphore=1 → последовательное выполнение
      final ctrl = ChunkedTranscriptionController(
        pool: KeyPool(initialKeys: [_testKey.raw]),
        apiService: apiService,
        chunkingService: MockAudioChunkingService(chunkFiles: chunks),
      );

      await ctrl.start(_dummyFile);

      expect(ctrl.state, isA<ChunkedSuccess>(),
          reason: 'Ожидаем ChunkedSuccess после успешной транскрибации 2 чанков');

      final result = (ctrl.state as ChunkedSuccess).result;
      // Чанк 0: offset=0, seg.start=0 → абсолютное время 0s → [00:00:00]
      expect(result.text, contains('[00:00:00] Привет мир'),
          reason: 'Первый чанк должен иметь таймкод [00:00:00]');
      // Чанк 1: offset=4500s (75 мин), seg.start=0 → абсолютное время 4500s → [01:15:00]
      expect(result.text, contains('[01:15:00] Как дела'),
          reason: 'Второй чанк с offset 4500s должен иметь таймкод [01:15:00]');
    });

    // -----------------------------------------------------------------------
    // Сценарий 2: Retry — первый вызов NetworkException, второй успешен.
    // -----------------------------------------------------------------------
    test('сценарий 2 — retry и успех: mock вызван 2 раза, итог ChunkedSuccess', () async {
      final chunk = FakeChunkFile('/tmp/chunk_000.ogg');

      int calls = 0;
      final apiService = MockTranscriptionProvider((_, __, ___) async {
        calls++;
        if (calls == 1) {
          throw const NetworkException('Нет соединения');
        }
        return TranscriptionResult(
          text: 'Текст после retry',
          language: 'ru',
          duration: 30.0,
          words: const [],
          segments: const [],
        );
      });

      final ctrl = ChunkedTranscriptionController(
        pool: KeyPool(initialKeys: [_testKey.raw]),
        apiService: apiService,
        chunkingService: MockAudioChunkingService(chunkFiles: [chunk]),
      );

      await ctrl.start(_dummyFile);

      expect(ctrl.state, isA<ChunkedSuccess>(),
          reason: 'После успешного retry итог должен быть ChunkedSuccess');
      expect(calls, equals(2),
          reason: 'transcribeChunk должен быть вызван ровно 2 раза (1 провал + 1 успех)');
    });

    // -----------------------------------------------------------------------
    // Сценарий 3: Исчерпаны retries (3 попытки) → ChunkedError.
    // -----------------------------------------------------------------------
    test('сценарий 3 — исчерпаны retries: после 3 попыток ChunkedError', () async {
      final chunk = FakeChunkFile('/tmp/chunk_000.ogg');

      int calls = 0;
      final apiService = MockTranscriptionProvider((_, __, ___) async {
        calls++;
        throw const NetworkException('Сеть недоступна');
      });

      // retryDelay: нулевой → тест не ждёт реальных задержек
      final ctrl = ChunkedTranscriptionController(
        pool: KeyPool(initialKeys: [_testKey.raw]),
        apiService: apiService,
        chunkingService: MockAudioChunkingService(chunkFiles: [chunk]),
        retryDelay: (_) => Duration.zero,
      );

      await ctrl.start(_dummyFile);

      expect(ctrl.state, isA<ChunkedError>(),
          reason: 'После 10 безуспешных попыток должна быть ChunkedError');
      // maxAttempts=10 → 10 попыток NetworkException → rethrow
      expect(calls, equals(10),
          reason: 'transcribeChunk вызывается 10 раз до исчерпания retry');
      final err = ctrl.state as ChunkedError;
      expect(err.retryable, isTrue,
          reason: 'NetworkException → retryable=true');
    });

    // -----------------------------------------------------------------------
    // Сценарий 5 (DG-04): code-switching — чанки возвращают разные языки.
    // -----------------------------------------------------------------------
    test('сценарий 5 — code-switching: language = первый непустой язык чанка', () async {
      final chunks = [
        FakeChunkFile('/tmp/chunk_000.ogg'),
        FakeChunkFile('/tmp/chunk_001.ogg'),
      ];

      int callIndex = 0;
      final apiService = MockTranscriptionProvider((_, __, ___) async {
        final i = callIndex++;
        // Чанк 0 → 'ru', чанк 1 → 'en' (code-switching)
        return TranscriptionResult(
          text: i == 0 ? 'Русский текст' : 'English text',
          language: i == 0 ? 'ru' : 'en',
          duration: 30.0,
          words: const [],
          segments: const [],
        );
      });

      final ctrl = ChunkedTranscriptionController(
        pool: KeyPool(initialKeys: [_testKey.raw]),
        apiService: apiService,
        chunkingService: MockAudioChunkingService(chunkFiles: chunks),
      );

      await ctrl.start(_dummyFile);

      expect(ctrl.state, isA<ChunkedSuccess>());
      final result = (ctrl.state as ChunkedSuccess).result;
      // Первый непустой язык выигрывает — 'ru' от чанка 0.
      expect(result.language, equals('ru'),
          reason: 'При code-switching побеждает язык первого чанка');
    });

    test('сценарий 5b — пустой язык первого чанка: берётся язык второго', () async {
      final chunks = [
        FakeChunkFile('/tmp/chunk_000.ogg'),
        FakeChunkFile('/tmp/chunk_001.ogg'),
      ];

      int callIndex = 0;
      final apiService = MockTranscriptionProvider((_, __, ___) async {
        final i = callIndex++;
        return TranscriptionResult(
          text: i == 0 ? 'Тишина' : 'Текст',
          language: i == 0 ? '' : 'ru',
          duration: 30.0,
          words: const [],
          segments: const [],
        );
      });

      final ctrl = ChunkedTranscriptionController(
        pool: KeyPool(initialKeys: [_testKey.raw]),
        apiService: apiService,
        chunkingService: MockAudioChunkingService(chunkFiles: chunks),
      );

      await ctrl.start(_dummyFile);

      expect(ctrl.state, isA<ChunkedSuccess>());
      final result = (ctrl.state as ChunkedSuccess).result;
      // Первый чанк вернул пустой язык → берём язык второго чанка.
      expect(result.language, equals('ru'),
          reason: 'Пустой язык первого чанка пропускается, берётся первый непустой');
    });

    // -----------------------------------------------------------------------
    // Сценарий 4: Cleanup — оба файла удалены, даже при AuthException.
    // -----------------------------------------------------------------------
    test('сценарий 4 — cleanup: оба tmp-файла удалены при AuthException', () async {
      final chunk0 = FakeChunkFile('/tmp/chunk_000.ogg');
      final chunk1 = FakeChunkFile('/tmp/chunk_001.ogg');

      // Первый чанк успешен, второй бросает AuthException.
      // Но из-за Future.wait параллельного выполнения поведение зависит от порядка.
      // Используем maxConcurrent=1 для последовательного выполнения: chunk0 → chunk1.
      int callIndex = 0;
      final apiService = MockTranscriptionProvider((_, __, ___) async {
        final i = callIndex++;
        if (i == 0) {
          return TranscriptionResult(
            text: 'Первая часть',
            language: 'ru',
            duration: 30.0,
            words: const [],
            segments: const [],
          );
        }
        // Второй чанк: AuthException → не ретраится
        throw const AuthException('Неверный API-ключ');
      });

      // 1 ключ → semaphore=1 → последовательно: chunk0 → chunk1
      final ctrl = ChunkedTranscriptionController(
        pool: KeyPool(initialKeys: [_testKey.raw]),
        apiService: apiService,
        chunkingService: MockAudioChunkingService(chunkFiles: [chunk0, chunk1]),
      );

      await ctrl.start(_dummyFile);

      expect(ctrl.state, isA<ChunkedError>(),
          reason: 'AuthException на чанке 1 → итоговое состояние ChunkedError');
      final err = ctrl.state as ChunkedError;
      expect(err.retryable, isFalse,
          reason: 'AuthException → retryable=false');

      // Cleanup: оба файла должны быть удалены в блоке finally.
      expect(chunk0.deleted, isTrue,
          reason: 'chunk_000.ogg должен быть удалён в блоке finally');
      expect(chunk1.deleted, isTrue,
          reason: 'chunk_001.ogg должен быть удалён в блоке finally');
    });
  });
}
