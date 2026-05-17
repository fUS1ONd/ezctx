---
phase: "02-real-lectures-chunking-progress"
plan: "02-01"
subsystem: "transcription"
tags: [ffmpeg, ffprobe, chunking, audio, metadata]
dependency_graph:
  requires:
    - "lib/core/error/app_exception.dart"
    - "ffmpeg_kit_flutter_new ^4.1.0"
    - "path_provider ^2.1.5"
    - "path ^1.8.0"
  provides:
    - "AudioMetadata — модель метаданных аудиофайла"
    - "AudioChunkingService — ffprobe-метаданные + ffmpeg-разбивка на чанки"
  affects:
    - "Plan 02-02: ChunkedTranscriptionController будет использовать AudioChunkingService"
tech_stack:
  added: []
  patterns:
    - "Injectable override callbacks (_probeOverride / _ffmpegOverride) для тестируемости нативных плагинов без mockito"
    - "Completer<void> для оборачивания executeAsync в awaitable Future"
key_files:
  created:
    - "lib/features/transcription/audio_metadata.dart"
    - "lib/features/transcription/audio_chunking_service.dart"
    - "test/features/transcription/audio_chunking_service_test.dart"
  modified: []
decisions:
  - "_probeOverride возвращает MediaInformation? (не MediaInformationSession) — нативный сессионный объект нельзя создать без платформы; MediaInformation конструируется напрямую через map"
  - "_ffmpegOverride принимает команду и возвращает Future<void> — тест бросает InternalException напрямую вместо создания нативного FFmpegSession"
metrics:
  duration: "~15 min"
  completed: "2026-05-17"
  tasks_completed: 2
  files_created: 3
  tests_passed: 5
requirements_covered:
  - IMPORT-03
  - IMPORT-04
  - TRANS-04
---

# Phase 02 Plan 01: AudioChunkingService — ffprobe-метаданные + ffmpeg-разбивка на чанки

**One-liner:** AudioChunkingService с injectable ffprobe/ffmpeg overrides: getMetadata() через FFprobeKit (ms→sec), split() segment 1200s 128k mono 16kHz в tmp dir, 5 unit-тестов без mockito.

## What Was Built

### AudioMetadata (`lib/features/transcription/audio_metadata.dart`)
Доменная модель метаданных аудиофайла:
- `name` — базовое имя файла
- `durationSeconds` — длительность в секундах (double)
- `sizeBytes` — размер в байтах (int)
- `durationFormatted` — геттер: "1:23:45" или "23:45"
- `sizeFormatted` — геттер: "123.4 МБ" / "45.6 КБ" / "N Б"
- `chunkCount(double)` — расчётное количество чанков

### AudioChunkingService (`lib/features/transcription/audio_chunking_service.dart`)
Сервис разбивки аудио:

**getMetadata(String filePath) → Future<AudioMetadata>:**
- Вызывает FFprobeKit.getMediaInformation() (или probeOverride в тестах)
- getDuration() возвращает строку в мс → делим на 1000.0
- При null или непарсируемой строке → бросает InternalException
- sizeBytes из File.statSync().size, name из path.basename()

**split(String filePath, {String? outputDir}) → Future<List<File>>:**
- Создаёт tmp dir `/tmp/ezctx_chunks_{timestamp}`
- Команда: `-i "..." -f segment -segment_time 1200 -c:a libmp3lame -b:a 128k -ac 1 -ar 16000 ".../chunk_%03d.mp3"`
- FFmpegKit.executeAsync обёрнут в Completer<void>
- При ошибке ffmpeg → бросает InternalException
- Возвращает список файлов chunk_*.mp3, отсортированных по имени

**Константа:** `kChunkDurationSeconds = 1200.0`

### Тесты (`test/features/transcription/audio_chunking_service_test.dart`)
5 тестов (все проходят):
1. getMetadata success: "5000" мс → durationSeconds == 5.0
2. getMetadata null duration → InternalException
3. getMetadata "abc" → InternalException
4. split success: ffmpegOverride без ошибки → List<File> [chunk_000, chunk_001]
5. split error: ffmpegOverride бросает → InternalException

## Commits

| Hash    | Message                                              |
|---------|------------------------------------------------------|
| 210a684 | feat(02-01): AudioMetadata + AudioChunkingService + unit tests |

## Deviations from Plan

### Auto-changed Design (not a deviation rule — planned API refinement)

**Override signature изменена по сравнению с планом:**
- **Plan:** `_probeOverride: Future<MediaInformationSession> Function(String)`
- **Actual:** `_probeOverride: Future<MediaInformation?> Function(String)`
- **Reason:** `MediaInformationSession` — нативный объект, создать без platform channel невозможно. `MediaInformation(Map)` — plain Dart, конструируется напрямую.

- **Plan:** `_ffmpegOverride: Future<FFmpegSession> Function(String, void Function(FFmpegSession))`
- **Actual:** `_ffmpegOverride: Future<void> Function(String command)`
- **Reason:** `FFmpegSession` — нативный объект. Override как `Future<void>` элегантнее: тест бросает ошибку напрямую, без создания нативного объекта.

Оба изменения улучшают тестируемость и не меняют внешний API сервиса для Plan 02-02.

## Threat Flags

Нет новых security-поверхностей (сервис работает с локальными файлами, не с сетью).

## Self-Check: PASSED

- [x] `lib/features/transcription/audio_metadata.dart` — FOUND
- [x] `lib/features/transcription/audio_chunking_service.dart` — FOUND
- [x] `test/features/transcription/audio_chunking_service_test.dart` — FOUND
- [x] Commit 210a684 — FOUND
- [x] 5/5 тестов прошли
