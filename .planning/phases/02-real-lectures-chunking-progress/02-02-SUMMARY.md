---
phase: "02-real-lectures-chunking-progress"
plan: "02-02"
subsystem: "transcription"
tags: [chunking, parallelism, retry, timecodes, controller]
dependency_graph:
  requires: [02-01]
  provides: [ChunkedTranscriptionController, ChunkState, RateLimitException, TranscriptionSegment]
  affects: [groq_api_service, transcription_result, app_exception]
tech_stack:
  added: [_Semaphore (custom Completer-based)]
  patterns: [ChangeNotifier, sealed classes, exponential backoff, bounded concurrency]
key_files:
  created:
    - lib/features/transcription/chunk_state.dart
    - lib/features/transcription/chunked_transcription_controller.dart
    - test/features/transcription/chunked_transcription_controller_test.dart
  modified:
    - lib/core/error/app_exception.dart
    - lib/features/transcription/transcription_result.dart
    - lib/features/transcription/groq_api_service.dart
decisions:
  - "Ручные моки вместо @GenerateMocks: File — абстрактный класс, implements надёжнее в данном окружении"
  - "chunkDuration использует константу kChunkDurationSeconds=1200.0 (не метаданные файла)"
  - "_withRetry: экспоненциальный backoff 5s→10s→20s, maxRetries=3"
metrics:
  duration: "~15 минут"
  completed: "2026-05-17"
  tasks_completed: 3
  files_count: 6
---

# Phase 02 Plan 02: ChunkedTranscriptionController — параллельность + retry + сборка

**One-liner:** ChunkedTranscriptionController с bounded concurrency (_Semaphore, max 3), exponential retry, сборкой текста по таймкодам [HH:MM:SS] и cleanup tmp-файлов в finally.

## What Was Built

### Task 1: ChunkState + доменные модели (commit bd05e91)

- **chunk_state.dart** — sealed class `ChunkState` с 5 подклассами: `ChunkWaiting`, `ChunkUploading`, `ChunkDone`, `ChunkRetrying(attempt)`, `ChunkFailed(error)`. Каждый подкласс хранит `index` и человекочитаемый `label`.
- **app_exception.dart** — добавлен `RateLimitException` (HTTP 429 от Groq; ретраится).
- **transcription_result.dart** — добавлен `TranscriptionSegment(start, end, text)` и поле `segments: List<TranscriptionSegment>` в `TranscriptionResult`. `fromJson` обратно совместим — `segments` defaults to `const []`.

### Task 2: GroqApiService.transcribeChunk() + ChunkedTranscriptionController (commit b9ef9e9)

- **groq_api_service.dart** — метод `transcribeChunk({bytes, filename, apiKey})`: полная обработка статусов (200, 401→AuthException, 429→RateLimitException, 5xx→NetworkException), 5-минутный timeout, финальный `client.close()` в `finally`.
- **chunked_transcription_controller.dart**:
  - Приватный `_Semaphore` — ограничивает параллельность через счётчик + очередь Completer.
  - `ChunkedState` sealed hierarchy: Idle, Splitting, Processing, Success, Error, MissingKey.
  - `ChunkedTranscriptionController.start(SelectedAudioFile)`: split → Future.wait с семафором → retry → assemble → cleanup.
  - `_withRetry`: ретраит `NetworkException`/`RateLimitException` (backoff 5→10→20с, max 3 попытки), `AuthException` — немедленный rethrow.
  - `_assembleResult`: для каждого сегмента `absoluteStart = i * 1200 + seg.start` → форматирует `[HH:MM:SS] text`.
  - Cleanup tmp-чанков в `finally` (независимо от ошибки).

### Task 3: Юнит-тесты (commit 4bfe749)

7 тестов, все проходят:
1. Успех: один чанк → ChunkedSuccess с текстом
2. Retry: NetworkException на первом вызове → ChunkedSuccess после второго
3. AuthException: не ретраится, вызов ровно 1 раз, retryable=false
4. Параллельность: maxConcurrent=2 при 5 чанках — одновременно не более 2
5. Таймкоды: [00:00:00] для chunk 0, [00:20:00] и [00:20:05] для chunk 1 (offset 1200s)
6. Cleanup: все 3 tmp-файла помечены deleted после start()
7. ChunkedMissingKey при пустом списке ключей

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Ручные моки вместо @GenerateMocks**
- **Found during:** Task 3
- **Issue:** `File` — абстрактный класс, `extends File` требует вызова `super(path)` которого нет. `@GenerateMocks([AudioChunkingService])` не нужен — класс не имеет `@mockable`-совместимого конструктора из-за ffmpeg зависимостей.
- **Fix:** Реализован `_FakeChunkFile implements File` + ручные моки для всех трёх зависимостей.
- **Files modified:** test/features/transcription/chunked_transcription_controller_test.dart

## Self-Check: PASSED

- lib/features/transcription/chunk_state.dart — FOUND
- lib/features/transcription/chunked_transcription_controller.dart — FOUND
- lib/features/transcription/groq_api_service.dart — FOUND (modified)
- lib/features/transcription/transcription_result.dart — FOUND (modified)
- lib/core/error/app_exception.dart — FOUND (modified)
- test/features/transcription/chunked_transcription_controller_test.dart — FOUND
- Commit bd05e91 — FOUND
- Commit b9ef9e9 — FOUND
- Commit 4bfe749 — FOUND
- Tests: 7/7 passed
