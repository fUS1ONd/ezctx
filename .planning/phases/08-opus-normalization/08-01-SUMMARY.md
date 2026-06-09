---
phase: 08-opus-normalization
plan: "01"
subsystem: audio
tags: [ffmpeg, opus, ogg, normalization, flutter, dart]

# Dependency graph
requires:
  - phase: 07-groq-refactor
    provides: AudioNormalizationService с инжектируемым ffmpegOverride/outputPathOverride

provides:
  - AudioNormalizationService использует libopus 48k/16kHz/Mono в контейнере .ogg
  - Тесты нормализации ловят регресс на opus-инвариантах (-vn, -c:a libopus, .ogg)

affects: [08-02-chunking, 08-03-groq-mime, groq-transcription-pipeline]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "opus 48k/16kHz/Mono (.ogg) как стандарт нормализации аудио для ASR"
    - "-vn defensive-флаг для отбрасывания видеодорожки (вход может быть mp4/webm)"

key-files:
  created: []
  modified:
    - lib/features/transcription/audio_normalization_service.dart
    - test/features/transcription/audio_normalization_service_test.dart

key-decisions:
  - "libopus доступен в Full-GPL сборке ffmpeg_kit_flutter_new 4.1.0 — fallback на mp3 не нужен"
  - "Флаг -vn добавлен defensively: исключает muxer-ошибку при видео-входе (mp4/webm)"
  - "Выходной контейнер .ogg (OGG Opus, RFC 7845) вместо .mp3 32k"

patterns-established:
  - "Команда нормализации: -i \"$inputPath\" -vn -c:a libopus -b:a 48k -ac 1 -ar 16000 -y \"$outPath\""
  - "Шаблон выходного пути: ezctx_norm_<timestamp>.ogg"

requirements-completed: [NORM-01, NORM-02]

# Metrics
duration: 8min
completed: 2026-06-09
---

# Phase 08 Plan 01: Нормализация opus Summary

**AudioNormalizationService переведён с libmp3lame 32k (.mp3) на libopus 48k (.ogg) с флагом -vn; тесты обновлены и зелёные на opus-инвариантах**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-06-09T15:48:00Z
- **Completed:** 2026-06-09T15:56:15Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Команда ffmpeg нормализации обновлена: `-i "$inputPath" -vn -c:a libopus -b:a 48k -ac 1 -ar 16000 -y "$outPath"`
- Шаблон выходного пути изменён с `ezctx_norm_<ts>.mp3` на `ezctx_norm_<ts>.ogg`
- Docstring класса и метода normalize обновлён: «mp3 32k/16kHz/Mono» → «opus 48k/16kHz/Mono (.ogg)»
- Тесты нормализации обновлены: ассерты на `-c:a libopus`, `-vn`, `endsWith('.ogg')`; негативный ассерт `isNot(contains('libmp3lame'))`; все 4 теста зелёные

## Task Commits

1. **Task 1: Перевести нормализацию на opus 48k/.ogg** - `1982841` (feat)
2. **Task 2: Обновить тесты нормализации под opus/.ogg** - `e3be5f6` (test)

## Files Created/Modified

- `lib/features/transcription/audio_normalization_service.dart` — заменена ffmpeg-команда нормализации (libmp3lame 32k → libopus 48k), шаблон пути .mp3 → .ogg, обновлены комментарии
- `test/features/transcription/audio_normalization_service_test.dart` — обновлены ассерты на opus-инварианты (-c:a libopus, -vn, .ogg), изменены фикстуры выходных файлов

## Decisions Made

- **libopus без fallback:** libopus VERIFIED в Full-GPL сборке `ffmpeg_kit_flutter_new 4.1.0` — отдельный fallback не нужен
- **Флаг -vn обязателен:** вход может быть mp4/webm; `-vn` defensive-отбрасывает видеодорожку до opus-энкодера, исключая muxer-ошибку. Overhead нулевой
- **Контейнер .ogg:** OGG Opus (RFC 7845) принимается Groq и будущим Deepgram

## Deviations from Plan

Нет — план выполнен в точности как написан.

## Issues Encountered

Нет.

## User Setup Required

Нет — внешней конфигурации не требуется.

## Next Phase Readiness

- NORM-01 и NORM-02 выполнены: команда нормализации содержит `-vn -c:a libopus -b:a 48k -ac 1 -ar 16000`, выход `.ogg`
- Готово для 08-02 (обновление чанкинга: паттерн chunk_%03d.ogg, kChunkThresholdSeconds 4920→3240)
- Готово для 08-03 (обновление MIME в GroqApiService: audio/mpeg → audio/ogg)

---
*Phase: 08-opus-normalization*
*Completed: 2026-06-09*
