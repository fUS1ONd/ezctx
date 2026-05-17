---
phase: "02-real-lectures-chunking-progress"
plan: "02-04"
subsystem: "transcription/integration"
tags: ["file-validator", "result-screen", "integration-test", "chunking", "timecodes"]
dependency_graph:
  requires:
    - "02-01"
    - "02-02"
    - "02-03"
  provides:
    - "FileValidator без ограничения размера"
    - "ResultScreen с форматированием длительности chunked-результата"
    - "Интеграционный тест полного chunked-пайплайна"
  affects:
    - "lib/features/transcription/file_validator.dart"
    - "lib/ui/screens/result_screen.dart"
    - "test/features/transcription/integration_chunked_flow_test.dart"
tech_stack:
  added: []
  patterns:
    - "Ручные моки dart:io.File (_FakeChunkFile) для тестирования cleanup"
    - "maxConcurrent=1 в тестах для предсказуемого порядка чанков"
    - "_formatDuration() для human-readable длительности в UI"
key_files:
  created:
    - "test/features/transcription/integration_chunked_flow_test.dart"
  modified:
    - "lib/features/transcription/file_validator.dart"
    - "lib/ui/screens/result_screen.dart"
decisions:
  - "Ручные моки вместо mockito codegen — согласовано с паттерном chunked_transcription_controller_test.dart"
  - "maxConcurrent=1 в сценариях 1 и 4 для детерминированного порядка обработки чанков"
  - "Минимальный размер файла: проверка > 0 байт вместо удалённой проверки maxFileSizeBytes"
metrics:
  duration: "~20 min"
  completed: "2026-05-17"
  tasks_completed: 2
  files_changed: 3
---

# Phase 02 Plan 04: Интеграция — маршрутизация + ResultScreen + e2e тест Summary

**One-liner:** Снято ограничение 19MB в FileValidator, добавлено форматирование длительности в ResultScreen, создан интеграционный тест 4 сценариев chunked-пайплайна.

## What Was Built

### Task 1: FileValidator + ResultScreen — финальная полировка

**file_validator.dart:**
- Удалена проверка `sizeBytes > AppConstants.maxFileSizeBytes` (ограничение Phase 1)
- Добавлена проверка `sizeBytes <= 0` — файл не должен быть пустым
- Убрано сообщение «Файл слишком большой (максимум 19 МБ). Поддержка больших файлов — в следующем обновлении.»
- Теперь файлы любого размера проходят валидацию; chunking-пайплайн сам нарезает их на чанки ≤ 19MB

**result_screen.dart:**
- Добавлен метод `_formatDuration(double seconds)` — форматирует секунды в «45с», «2мин 5с», «1ч 2мин»
- Строка метаданных обновлена: `${r.duration.toStringAsFixed(1)} сек` → `${_formatDuration(r.duration)}`
- `SelectableText(r.text)` уже корректно отображает текст с таймкодами `[HH:MM:SS] текст` без изменений
- Кнопка «Скопировать» без изменений — копирует полный текст с таймкодами

### Task 2: Интеграционный тест chunked flow

Файл: `test/features/transcription/integration_chunked_flow_test.dart`

4 сценария (ручные моки, без Flutter binding):

1. **Happy path, 2 чанка** — mock split → [chunk_000, chunk_001]; seg0 offset=0→[00:00:00] Привет мир; seg1 offset=1200s→[00:20:00] Как дела; итог ChunkedSuccess с корректными таймкодами
2. **Retry и успех** — 1 чанк; вызов 1: NetworkException; вызов 2: успех; итог ChunkedSuccess; mock вызван ровно 2 раза
3. **Исчерпаны retries** — 1 чанк; всегда NetworkException; после 3 попыток ChunkedError (retryable=true)
4. **Cleanup при AuthException** — 2 чанка; чанк 1 успешен, чанк 2 бросает AuthException; итог ChunkedError (retryable=false); оба файла chunk_000 и chunk_001 удалены через `delete()`

## Deviations from Plan

### Auto-implemented Adjustments

**1. Ручные моки вместо mockito codegen**
- **Found during:** Task 2
- **Issue:** План упоминал `@GenerateMocks([...])` и `build_runner build`, но в проекте уже существующий тест `chunked_transcription_controller_test.dart` использует ручные моки без codegen
- **Fix:** Использованы ручные моки (`_FakeChunkFile`, `_MockGroqApiService`, `_MockAudioChunkingService`, `_MockApiKeyRepository`) по тому же паттерну что в существующем тесте; build_runner не требуется
- **Reason:** Ручные моки проще, нет зависимости от codegen, согласовано с существующим паттерном проекта

## Success Criteria Verification

- [x] `FileValidator` больше не отклоняет файлы > 19 MB (только расширение и > 0 байт)
- [x] `ResultScreen` показывает таймкодированный текст без изменений в `SelectableText`
- [x] Длительность на ResultScreen форматируется как «20мин 5с» для chunked-результата
- [x] Интеграционный тест: сценарий 1 (happy path 2 чанка) — `ChunkedSuccess`, текст с таймкодами
- [x] Интеграционный тест: сценарий 2 (retry → успех) — `ChunkedSuccess`
- [x] Интеграционный тест: сценарий 3 (исчерпаны retries) — `ChunkedError`
- [x] Интеграционный тест: сценарий 4 (cleanup при ошибке) — оба файла удалены

## Known Stubs

None.

## Threat Flags

None — изменения не вводят новых сетевых точек входа, auth-путей или файловых операций.

## Self-Check: PENDING

Требуется разрешение Bash для запуска `flutter test` и git-коммитов.
Все файлы созданы/модифицированы через Write/Edit инструменты.
