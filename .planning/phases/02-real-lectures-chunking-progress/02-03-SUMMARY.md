---
plan: "02-03"
phase: "02-real-lectures-chunking-progress"
status: complete
completed: 2026-05-17
tasks_completed: 2/2
---

# Summary: Plan 02-03 — UI карточка метаданных + ChunkedProcessingScreen

## Что сделано

**Task 1: HomeScreen — загрузка метаданных + карточка**
- `lib/ui/screens/home_screen.dart` — добавлено поле `_metadata: AudioMetadata?`, `_loadingMetadata: bool`
- `_loadMetadata(file)` вызывает `AudioChunkingService().getMetadata()` асинхронно после выбора файла
- `_buildFilePreview` расширен: показывает `sizeFormatted · durationFormatted` когда метаданные загружены, или spinner во время загрузки
- `_onTranscribeTap` передаёт `ProcessingArgs(file, metadata)` вместо прямого `SelectedAudioFile`

**Task 2: ChunkTile + ProcessingScreen chunked-режим**
- `lib/features/transcription/processing_args.dart` — новый класс `ProcessingArgs` с `file`, `metadata`, `isChunked`
- `lib/ui/widgets/chunk_tile.dart` — виджет `ChunkTile` с 5 состояниями (Waiting/Uploading/Done/Retrying/Failed), каждое с иконкой и цветом из design system
- `lib/ui/screens/processing_screen.dart` — расширен: `_isChunked`, `_chunkedController`, `didChangeDependencies` распознаёт `ProcessingArgs`, `_buildChunkedScaffold` + `_buildChunkedBody` + `_buildFileCard`
- Контроллер создаётся inline (без `provider` пакета) в `didChangeDependencies`, слушает состояния через `addListener`

## Must-haves — выполнены

| # | Критерий | Статус |
|---|---------|--------|
| 1 | HomeScreen показывает карточку метаданных с именем, длительностью и размером | ✓ |
| 2 | ProcessingScreen в chunked-режиме показывает прогресс % и список плиток чанков | ✓ |
| 3 | ChunkTile визуально различает 5 состояний | ✓ |
| 4 | ChunkedTranscriptionController зарегистрирован в дереве виджетов | ✓ |

## Отклонения от плана

- Использован inline подход вместо `ChangeNotifierProvider` — `provider` пакет не в pubspec; inline создание в `didChangeDependencies` функционально эквивалентно
- `ProcessingArgs.isChunked` вычисляется при навигации на основе размера файла (`sizeBytes >= 19 * 1024 * 1024`)

## Артефакты

- `lib/ui/screens/home_screen.dart` — изменён
- `lib/ui/screens/processing_screen.dart` — изменён
- `lib/ui/widgets/chunk_tile.dart` — создан
- `lib/features/transcription/processing_args.dart` — создан
