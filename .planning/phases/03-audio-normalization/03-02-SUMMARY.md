---
phase: "03"
plan: "02"
subsystem: processing-screen
tags: [normalization, pipeline, ui, chunking]
dependency_graph:
  requires: [03-01]
  provides: [normalization-pipeline-ui]
  affects: [processing_screen.dart, processing_args.dart]
tech_stack:
  added: []
  patterns: [postFrameCallback-async-start, dispose-cleanup-tempfile]
key_files:
  modified:
    - lib/features/transcription/processing_args.dart
    - lib/ui/screens/processing_screen.dart
decisions:
  - isChunked теперь определяется по длительности нормализованного mp3, а не по размеру исходного файла
  - _startProcessing() запускается через addPostFrameCallback для безопасного доступа к контексту
  - Нормализованный временный файл удаляется в dispose()
metrics:
  duration: "~15min"
  completed: "2026-05-17"
---

# Phase 03 Plan 02: isChunked миграция + нормализация в ProcessingScreen Summary

**One-liner:** Убран size-based isChunked из ProcessingArgs; ProcessingScreen теперь запускает AudioNormalizationService как первый шаг pipeline с UI «Подготовка аудио…».

## What Was Built

### Task 1: Удалён isChunked из ProcessingArgs

Удалён getter `bool get isChunked => file.sizeBytes >= 19 * 1024 * 1024` и комментарий к нему. ProcessingArgs теперь содержит только `file`, `metadata` и конструктор — без логики определения режима обработки.

### Task 2: Интеграция нормализации в ProcessingScreen

1. Добавлены импорты `AudioNormalizationService` и `NormalizedAudioFile`.
2. Добавлены поля `_normalizing`, `_normalizedFile`, `_normalizationError`.
3. `didChangeDependencies` больше не читает `args.isChunked`; запуск идёт через `_startProcessing()` via `addPostFrameCallback`.
4. Метод `_startProcessing()` реализует полный pipeline: нормализация → определение `_isChunked` по длительности → запуск ChunkedTranscriptionController или TranscriptionController.
5. `dispose()` удаляет временный нормализованный файл.
6. `_restart()` сбрасывает `_normalizationError`/`_normalizedFile` и перезапускает `_startProcessing()`.
7. В `build()` добавлена ветка нормализации: ShimmerBar + «Подготовка аудио…» текст.
8. Pipeline GlassCard расширен шагом «Подготовка аудио» между «Загрузка» и «Распознавание».
9. Добавлена панель ошибки нормализации `_buildNormalizationError()` с кнопкой «Повторить».

## Commits

| Task | Commit | Message |
|------|--------|---------|
| 1+2  | 4da49e3 | feat(03-02): isChunked миграция + нормализация в ProcessingScreen |

## Deviations from Plan

### Auto-added improvements

**1. [Rule 2 - Missing critical functionality] Панель ошибки нормализации**
- **Found during:** Task 2
- **Issue:** План предусматривал `_normalizationError` поле, но не включал отдельный виджет `_buildNormalizationError()`.
- **Fix:** Добавлен отдельный метод с полноценным UI ошибки (сообщение + «Повторить» + «Назад»).
- **Files modified:** `processing_screen.dart`

**2. [Rule 2 - Missing critical functionality] Статус pending для шага «Подготовка аудио» при ошибке**
- **Issue:** В плане не было обработки `_normalizationError != null` в статусе pipeline-шага.
- **Fix:** Добавлен `_PipelineStatus.error` вариант при `_normalizationError != null`.

## Known Stubs

- `AudioNormalizationService` и `NormalizedAudioFile` импортируются, но файлы создаются в плане 03-01. До завершения Wave 1 (03-01 + 03-02) проект не компилируется — это ожидаемо по условию параллельного выполнения.

## Self-Check: PASSED

- `grep -c "_normalizing"` → 9 (поле, setState, условия в build)
- `grep -c "AudioNormalizationService"` → 1 (импорт)
- `grep -c "Подготовка аудио"` → 2 (pipeline шаг + текст при нормализации)
- `grep -c "isChunked" processing_args.dart` → 0 (getter удалён)
- Коммит 4da49e3 существует в git log
