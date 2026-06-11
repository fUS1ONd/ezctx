---
phase: 09-keypool-concurrency
plan: "03"
subsystem: transcription
tags: [refactor, tdd, controller, key-pool, provider-agnostic]
dependency_graph:
  requires: [09-01, 09-02]
  provides: [provider-agnostic-controller, concurrency-policy-tests, key-exhausted-handling]
  affects: [chunked_transcription_controller, test-helpers]
tech_stack:
  added: []
  patterns: [tdd-red-green, shared-test-helpers, on-exception-branch]
key_files:
  created:
    - test/helpers/transcription_mocks.dart
  modified:
    - lib/features/transcription/chunked_transcription_controller.dart
    - test/features/transcription/chunked_transcription_controller_test.dart
    - test/features/transcription/integration_chunked_flow_test.dart
decisions:
  - AudioMetadata import added to chunked_transcription_controller_test.dart (missing in original)
  - GREEN phase immediate — KeyExhaustedException branch (Task 2) made R-08 pass without extra code
metrics:
  duration: "~15 min"
  completed: "2026-06-09"
  tasks_completed: 3
  files_modified: 4
---

# Phase 09 Plan 03: Provider-Agnostic Controller + R-06/R-07/R-08 Coverage Summary

Controller fully decoupled from GroqKeyPool — KeyPool type substituted, `.ogg` filename fixed, `KeyExhaustedException` branch added without disrupting retry counters; test helpers extracted to shared module; R-06/R-07/R-08 tests green.

## Tasks Completed

| Task | Name | Commit | Status |
|------|------|--------|--------|
| 1 | Вынести тестовые mock'и в test/helpers/ | e8c0df4 | done |
| 2 | Контроллер на KeyPool + KeyExhaustedException + .ogg fix | 713d411 | done |
| 3 | Тесты R-06/R-07/R-08 (TDD RED → GREEN) | 1920237 | done |

## What Was Built

- `test/helpers/transcription_mocks.dart` — единая точка правды для тестовых моков. `MockTranscriptionProvider` принимает необязательный `concurrencyPolicy` (для Deepgram-сценариев) и `providerId`. `FakeChunkFile` и `MockAudioChunkingService` публичны.
- `ChunkedTranscriptionController` — тип пула сменён с `GroqKeyPool` → `KeyPool` (import + constructor + field). Filename `.mp3` → `.ogg`. В `_processChunk` добавлена ветка `on KeyExhaustedException`: вызывает `_pool.reportExhausted(key)` и переводит чанк в `ChunkRetrying(attempt: 0)` без инкремента `networkAttempt`/`rateLimitAttempt` и без rethrow.
- Тесты R-06 (Groq политика 1→1, 3→3), R-07 (Deepgram политика 1→5, 0→0), R-08 (exhausted ключ → reportExhausted, aliveKeyCount уменьшился, callCount==2) — все зелёные.
- R-09 регрессия: все 7+4 существующих теста контроллера и интеграционных зелёные.
- Полный `flutter test`: 97 тестов (94 passed + 1 skipped smoke test + 2 R-06/R-07 + R-08 = итого 97 successful), exit code 0.

## TDD Gate Compliance

- RED commit: `1920237` — тесты R-06/R-07/R-08 добавлены
- GREEN: тесты прошли немедленно — реализация (Task 2) уже содержала ветку KeyExhaustedException и MockTranscriptionProvider с concurrencyPolicy (Task 1)
- REFACTOR: не требовался

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Missing import] AudioMetadata import в controller_test**
- **Found during:** Task 2 первый запуск тестов
- **Issue:** `chunked_transcription_controller_test.dart` использует `AudioMetadata` в тесте таймкодов (строка 198), но импорт не был включён при переписывании файла
- **Fix:** добавлен `import 'package:ezctx/features/transcription/audio_metadata.dart';`
- **Files modified:** `test/features/transcription/chunked_transcription_controller_test.dart`
- **Commit:** включено в `713d411`

**2. [Plan instruction reconciliation] groq_key_pool.dart уже удалён**
- Инструкция Task 1 «Импорты groq_key_pool.dart НЕ менять» предполагала, что файл ещё существует. По состоянию worktree файл уже удалён (план 09-02). Импорты `key_pool.dart` применены сразу в Task 1 при переписывании тест-файлов с нуля — нет функционального расхождения с намерением плана.

## Self-Check

- [x] `test/helpers/transcription_mocks.dart` — FOUND
- [x] `lib/features/transcription/chunked_transcription_controller.dart` — FOUND
- [x] `test/features/transcription/chunked_transcription_controller_test.dart` — FOUND
- [x] `test/features/transcription/integration_chunked_flow_test.dart` — FOUND
- [x] commit e8c0df4 — Task 1
- [x] commit 713d411 — Task 2
- [x] commit 1920237 — Task 3 RED
- [x] `grep GroqKeyPool lib/.../chunked_transcription_controller.dart` → 0
- [x] `grep .mp3 lib/.../chunked_transcription_controller.dart` → 0
- [x] `flutter test` exit code 0

## Self-Check: PASSED

## Threat Surface Scan

No new network endpoints, auth paths, or schema changes introduced. Pure refactor + test coverage. No threat flags.
