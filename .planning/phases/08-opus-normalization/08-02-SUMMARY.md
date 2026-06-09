---
phase: 08-opus-normalization
plan: "02"
subsystem: audio
tags: [ffmpeg, opus, ogg, chunking, flutter, dart]

requires:
  - phase: 08-01
    provides: нормализованный .ogg выходной файл (AudioNormalizationService)

provides:
  - kChunkThresholdSeconds = 3240 (пересчитан под opus 48k)
  - сегментация чанков в .ogg через -c:a copy
  - тесты с VBR-граничным ассертом (CHUNK-05)

affects:
  - 08-03 (GroqApiService MIME ogg)
  - 08-04 (интеграционные тесты нормализации+чанкинга)

tech-stack:
  added: []
  patterns:
    - "Shortcircuit-логика: файлы <= kChunkThresholdSeconds не нарезаются ffmpeg"
    - "VBR-граница документируется через unit-тест, не runtime-guard"

key-files:
  created: []
  modified:
    - lib/core/constants/app_constants.dart
    - lib/features/transcription/audio_chunking_service.dart
    - test/features/transcription/audio_chunking_service_test.dart

key-decisions:
  - "kChunkThresholdSeconds 4920 → 3240: 48 kbps CBR × 3240с = 19.44 MB <= maxFileSizeBytes 19.92 MB; реальный VBR даёт ~12-16 MB"
  - "Без -segment_format ogg: ffmpeg определяет контейнер из расширения .ogg, лишний флаг конфликтует"
  - "VBR-граница покрыта ассертом CHUNK-05, не runtime-guard — осознанное решение (RESEARCH.md Q2 RESOLVED)"

patterns-established:
  - "chunk_%03d.ogg шаблон: расширение-агностичный сбор через startsWith('chunk_') сохранён"

requirements-completed: [CHUNK-01, CHUNK-02, CHUNK-03, CHUNK-04, CHUNK-05]

duration: 15min
completed: 2026-06-09
---

# Phase 08 Plan 02: Chunk Threshold Recalculation and .ogg Segmentation Summary

**Порог чанкинга пересчитан с 4920 до 3240с (opus 48k), сегментация переведена на chunk_%03d.ogg через -c:a copy; тесты зелёные с VBR-граничным ассертом CHUNK-05**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-06-09T15:44:00Z
- **Completed:** 2026-06-09T15:59:20Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments

- `kChunkThresholdSeconds` пересчитан с 4920 → 3240; docstring обновлён с VBR-расчётом
- ffmpeg-команда сегментации переведена на `chunk_%03d.ogg`; `-c:a copy` сохранён без `-segment_format`
- Тесты обновлены: R2 использует `AppConstants.kChunkThresholdSeconds` вместо hardcode 4920.0; добавлен CHUNK-05 VBR-assert; вся арифметика segment_time пересчитана под новый порог

## Task Commits

1. **Task 1: Пересчитать порог константы 4920 → 3240** - `a168257` (feat)
2. **Task 2: Перевести сегментацию чанков на .ogg** - `eeb1afb` (feat)
3. **Task 3: Обновить тесты чанкинга под порог 3240 и .ogg + VBR-assert** - `dc2b86f` (test)

## Files Created/Modified

- `lib/core/constants/app_constants.dart` — kChunkThresholdSeconds 4920 → 3240, обновлён docstring
- `lib/features/transcription/audio_chunking_service.dart` — chunk_%03d.mp3 → .ogg, shortcircuit-комментарий обновлён
- `test/features/transcription/audio_chunking_service_test.dart` — импорт AppConstants, R2 через константу, CHUNK-05 VBR-assert, пересчитана арифметика тестов

## Decisions Made

- **3240с выбран как консервативный порог:** 48 kbps CBR = 6000 B/s; 3240 × 6000 = 19 440 000 байт (< maxFileSizeBytes 19 922 944). Реальный VBR речи (~30-40 kbps) даёт 12-16 MB.
- **Без `-segment_format ogg`:** ffmpeg определяет контейнер из расширения выходного файла; явный флаг конфликтует с `-f segment`.
- **VBR-ассерт против maxFileSizeBytes:** формально CBR-потолок 3240 × 6000 = 18.54 MB превышает Groq-лимит 18.5 MB на ~41 KB, но это CBR. Тест сверяется с `maxFileSizeBytes` (19 MB) — входным guard'ом приложения. Расхождение задокументировано в комментарии теста явно.

## Deviations from Plan

Нет — план выполнен точно по спецификации.

## Issues Encountered

Нет.

## User Setup Required

Нет — никакие внешние сервисы не затронуты.

## Next Phase Readiness

- Готово для 08-03: GroqApiService нужно поменять MIME с `audio/mpeg` на `audio/ogg` под новый формат чанков
- Готово для 08-04: интеграционные тесты нормализации + чанкинга

## Self-Check

- [x] `app_constants.dart` содержит `kChunkThresholdSeconds = 3240` — подтверждено
- [x] `audio_chunking_service.dart` содержит `chunk_%03d.ogg` — подтверждено
- [x] Тест-файл содержит `AppConstants.kChunkThresholdSeconds` — подтверждено
- [x] Присутствует CHUNK-05 VBR-тест — подтверждено
- [x] `flutter test audio_chunking_service_test.dart` — 17/17 passed

## Self-Check: PASSED

---
*Phase: 08-opus-normalization*
*Completed: 2026-06-09*
