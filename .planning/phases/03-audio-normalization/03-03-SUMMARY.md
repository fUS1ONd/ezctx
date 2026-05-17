---
phase: "03"
plan: "03"
subsystem: testing
tags: [tests, audio-normalization, chunking, tdd]
dependency_graph:
  requires: [03-01, 03-02]
  provides: [test-coverage-normalization]
  affects: [audio_normalization_service, audio_chunking_service]
tech_stack:
  added: []
  patterns: [ffmpegOverride, outputPathOverride, probeOverride]
key_files:
  created:
    - test/features/transcription/audio_normalization_service_test.dart
  modified:
    - lib/features/transcription/audio_normalization_service.dart
    - test/features/transcription/audio_chunking_service_test.dart
decisions:
  - outputPathOverride добавлен в AudioNormalizationService для обхода getTemporaryDirectory() в unit-тестах без Flutter binding
metrics:
  duration: "~10 мин"
  completed: "2026-05-17"
  tasks_completed: 2
  files_changed: 3
---

# Phase 03 Plan 03: Тесты нормализации + обновление AudioChunkingServiceTest Summary

Написаны тесты AudioNormalizationService (4 теста) и обновлён AudioChunkingServiceTest под -c:a copy + segment_time 4500. Все 14 тестов проходят зелёным.

## Tasks Completed

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| 1 | Создан audio_normalization_service_test.dart | 9c91403 | test/features/transcription/audio_normalization_service_test.dart |
| 2 | Обновлён audio_chunking_service_test.dart | 9c91403 | test/features/transcription/audio_chunking_service_test.dart |

## Test Results

### audio_normalization_service_test.dart (4/4)
- `команда содержит все обязательные флаги нормализации` — проверка `-b:a 32k`, `-ac 1`, `-ar 16000`, `-codec:a libmp3lame`, `-y`, result.durationSeconds == 300.0
- `входной путь присутствует в команде в кавычках` — проверка `"${tmp.path}"` в команде
- `выходной путь содержит ezctx_norm_ и оканчивается на .mp3` — проверка имени выходного файла
- `ошибка ffmpeg → InternalException` — проверка пробрасывания ошибки

### audio_chunking_service_test.dart (10/10)
- Все прежние тесты проходят
- Обновлён тест `ffmpeg-команда содержит -c:a copy и segment_time 4500 (нормализованный вход)`:
  - `segment_time 1200` → `segment_time 4500`
  - `-c:a libmp3lame` → `-c:a copy`
  - Удалены устаревшие проверки `-b:a 128k`, `-ac 1`, `-ar 16000`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] deleteSync() не принимает параметр onError**
- **Found during:** Task 1, при компиляции
- **Issue:** `File.deleteSync(onError: (_) {})` — нет такого параметра в Dart API
- **Fix:** Заменено на `try { tmp.deleteSync(); } catch (_) {}`
- **Files modified:** test/features/transcription/audio_normalization_service_test.dart

**2. [Rule 2 - Missing test infrastructure] getTemporaryDirectory() требует Flutter binding**
- **Found during:** Task 1, при запуске тестов
- **Issue:** `AudioNormalizationService.normalize()` вызывает `getTemporaryDirectory()`, которая требует инициализированного `ServicesBinding`. В unit-тестах binding не инициализирован.
- **Fix:** Добавлен параметр `outputPathOverride` в `AudioNormalizationService`. В тестах передаётся готовый путь в tmp-директории. Production-поведение не изменено.
- **Files modified:** lib/features/transcription/audio_normalization_service.dart

## Known Stubs

None.

## Threat Flags

None.

## Self-Check: PASSED

- test/features/transcription/audio_normalization_service_test.dart — FOUND
- test/features/transcription/audio_chunking_service_test.dart — FOUND (modified)
- lib/features/transcription/audio_normalization_service.dart — FOUND (modified)
- commit 9c91403 — FOUND
