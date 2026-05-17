---
phase: "03"
plan: "01"
subsystem: "audio-normalization"
tags: [ffmpeg, normalization, chunking, mp3]
key-files:
  created:
    - lib/features/transcription/normalized_audio_file.dart
    - lib/features/transcription/audio_normalization_service.dart
  modified:
    - lib/features/transcription/audio_chunking_service.dart
    - lib/core/constants/app_constants.dart
decisions:
  - "split() использует -c:a copy так как входной файл уже нормализован через AudioNormalizationService"
  - "kChunkDurationSeconds = 4500 (75 мин × 32k ≈ 17.6 МБ < 19 МБ лимита Groq)"
metrics:
  completed: "2026-05-17"
---

# Phase 03 Plan 01: AudioNormalizationService + обновление split() Summary

**One-liner:** ffmpeg-нормализация входного аудио в mp3 32k/16kHz/Mono с обновлением split() на -c:a copy и порогом чанка 4500 секунд.

## Выполненные изменения

### Созданные файлы

**`lib/features/transcription/normalized_audio_file.dart`**
Value object с двумя const-полями: `path` (путь к tmp mp3) и `durationSeconds` (длительность нормализованного файла).

**`lib/features/transcription/audio_normalization_service.dart`**
Сервис нормализации через ffmpeg: `-b:a 32k -ac 1 -ar 16000 -codec:a libmp3lame`. Поддерживает инъекцию `ffmpegOverride` для тестов. Использует `AudioChunkingService.getMetadata()` для чтения длительности результата.

### Изменённые файлы

**`lib/features/transcription/audio_chunking_service.dart`**
- `kChunkDurationSeconds`: 1200.0 → 4500.0
- `split()`: убраны флаги `-c:a libmp3lame -b:a 128k -ac 1 -ar 16000`, заменены на `-c:a copy` (файл уже нормализован)

**`lib/core/constants/app_constants.dart`**
Добавлены константы:
- `kChunkThresholdSeconds = 4500` — порог isChunked
- `kChunkDurationSeconds = 4500.0` — длительность одного чанка

## Коммит

- `130b5c1` — feat(03-01): AudioNormalizationService + обновление split() на -c:a copy

## Deviations from Plan

None — план выполнен точно как написан.

## Self-Check: PASSED

- normalized_audio_file.dart: FOUND
- audio_normalization_service.dart: FOUND
- kChunkThresholdSeconds = 4500 в app_constants.dart: 1 совпадение
- c:a copy в audio_chunking_service.dart: 2 совпадения
- AudioNormalizationService в audio_normalization_service.dart: 2 совпадения
