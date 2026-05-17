---
phase: 02-real-lectures-chunking-progress
verified: 2026-05-17T12:00:00Z
status: human_needed
score: 5/5
overrides_applied: 0
human_verification:
  - test: "Выбрать аудиофайл > 19 МБ на Android-устройстве и убедиться, что экран обработки переключается в chunked-режим"
    expected: "ProcessingArgs.isChunked == true, запускается ChunkedTranscriptionController, видны плитки чанков и прогресс-бар"
    why_human: "Логика переключения зависит от sizeBytes файла — невозможно проверить без реального файла и файловой системы Android"
  - test: "Убедиться, что карточка метаданных на HomeScreen показывает длительность файла (формат H:MM:SS или MM:SS)"
    expected: "После выбора файла в карточке появляется строка вида '145.2 МБ · 1:23:45'"
    why_human: "Требует реальный вызов ffprobe на устройстве — в тестовой среде ffprobe недоступен"
  - test: "Проверить текст-подсказку в empty state HomeScreen"
    expected: "Подсказка 'mp3, wav, m4a, ogg, flac · до 19 МБ' вводит в заблуждение — ограничение снято в Phase 2"
    why_human: "UI-несоответствие: file_validator.dart снял лимит 19 МБ, но текст в _buildEmptyCard не обновлён (строка 243 home_screen.dart). Требует решения: исправить или оставить как ориентир для пользователей."
---

# Phase 02: Real Lectures Chunking & Progress — Verification Report

**Phase Goal:** Пользователь может транскрибировать реальные лекционные записи (часовые файлы, сотни мегабайт), видя прогресс по чанкам.
**Verified:** 2026-05-17T12:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Пользователь видит метаданные файла (имя, длительность, размер) до запуска — длительность из ffprobe | VERIFIED | `home_screen.dart` вызывает `_loadMetadata()` → `AudioChunkingService().getMetadata()` → `FFprobeKit.getMediaInformation()`. `_buildFilePreview()` отображает `_metadata!.sizeFormatted` и `_metadata!.durationFormatted`. `AudioMetadata.durationFormatted` форматирует в `H:MM:SS` или `MM:SS`. |
| 2 | Файл ≥ 19 МБ автоматически режется ffmpeg на сегменты ≤ 19 МБ (1200 сек, mp3 128k) | VERIFIED | `ProcessingArgs.isChunked` = `file.sizeBytes >= 19 * 1024 * 1024`. `AudioChunkingService.split()` выполняет ffmpeg с `-f segment -segment_time 1200 -c:a libmp3lame -b:a 128k -ac 1 -ar 16000`. `FileValidator` снял ограничение максимального размера (комментарий строка 17). |
| 3 | Чанки отправляются параллельно; виден общий прогресс и статус по каждому чанку | VERIFIED | `ChunkedTranscriptionController.start()` использует `Future.wait()` + `_Semaphore(maxConcurrent)`. `processing_screen.dart` рендерит `LinearProgressIndicator(value: completedCount/totalCount)` + `ListView.builder` из `ChunkTile`. `ChunkTile` различает 5 состояний: ожидает/отправляется/готов/повтор/ошибка. |
| 4 | Транзиентные ошибки и 524 от Groq ретраятся с экспоненциальной задержкой | VERIFIED | `_withRetry()` ловит `NetworkException` и `RateLimitException`, делает до 3 попыток с `delay *= 2`. 524 от Groq попадает под `NetworkException` (строка 70 groq_api_service.dart: "5xx, 524 и прочие"). `AuthException` не ретраится. Тест `retry: NetworkException → второй вызов успешен` проходит. |
| 5 | Расшифровка собирается с таймкодами (offset = index * chunkDuration); tmp mp3-чанки удаляются | VERIFIED | `_assembleResult()` вычисляет `absoluteStart = i * chunkDuration + seg.start`, форматирует `[HH:MM:SS]`. Блок `finally` в `start()` удаляет все `chunkFiles`. Тест `таймкоды: chunk 0 → [00:00:00], chunk 1 offset 1200s → [00:20:00]` проходит. Тест `cleanup: все tmp-чанки удалены` проходит. |

**Score:** 5/5 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/features/transcription/audio_metadata.dart` | Модель метаданных с форматированием | VERIFIED | `durationFormatted`, `sizeFormatted`, `chunkCount()` — полная реализация |
| `lib/features/transcription/audio_chunking_service.dart` | ffprobe + ffmpeg split | VERIFIED | `getMetadata()` через FFprobeKit, `split()` через FFmpegKit.executeAsync, инжектируемые override для тестов |
| `lib/features/transcription/chunk_state.dart` | 5 состояний чанка | VERIFIED | sealed class с `ChunkWaiting`, `ChunkUploading`, `ChunkDone`, `ChunkRetrying`, `ChunkFailed` |
| `lib/features/transcription/chunked_transcription_controller.dart` | Контроллер пайплайна | VERIFIED | `_Semaphore`, `Future.wait()`, `_withRetry()` с экспоненциальным backoff, `_assembleResult()` с таймкодами, cleanup в finally |
| `lib/features/transcription/groq_api_service.dart` | `transcribeChunk` метод | VERIFIED | Принимает `bytes+filename+apiKey`, обрабатывает 401/429/5xx/524, бросает типизированные исключения |
| `lib/features/transcription/transcription_result.dart` | `TranscriptionSegment` | VERIFIED | `start`, `end`, `text`; `TranscriptionResult.segments` — список сегментов из verbose_json |
| `lib/ui/widgets/chunk_tile.dart` | UI-плитка состояния чанка | VERIFIED | `_resolveVisuals()` через switch на sealed class, CircularProgressIndicator для ChunkUploading |
| `lib/ui/screens/home_screen.dart` | Карточка метаданных | VERIFIED | `_loadMetadata()` вызывает ffprobe, `_buildFilePreview()` показывает имя+размер+длительность |
| `lib/ui/screens/processing_screen.dart` | Chunked-режим UI | VERIFIED | `_buildChunkedScaffold()` + `_buildChunkedBody()` с LinearProgressIndicator + ListView из ChunkTile |
| `lib/features/transcription/file_validator.dart` | Лимит 19 МБ снят | VERIFIED | Валидирует только расширение и `sizeBytes > 0`, комментарий явно указывает на снятие ограничения в Phase 2 |
| `test/features/transcription/audio_chunking_service_test.dart` | Тесты getMetadata + split | VERIFIED | 5 тестов — все проходят |
| `test/features/transcription/chunked_transcription_controller_test.dart` | Тесты контроллера | VERIFIED | 7 тестов — все проходят |
| `test/features/transcription/integration_chunked_flow_test.dart` | Интеграционные тесты | VERIFIED | 4 сценария — все проходят |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `home_screen.dart` | `AudioChunkingService.getMetadata()` | `_loadMetadata()` → `AudioChunkingService()` | WIRED | Импортирует и вызывает; результат записывается в `_metadata` и рендерится |
| `home_screen.dart` | `ProcessingScreen` | `Navigator.pushNamed(routeProcessing, arguments: ProcessingArgs(...))` | WIRED | `ProcessingArgs` передаётся с `file` и `metadata` |
| `ProcessingArgs` | chunked-режим | `isChunked` getter: `sizeBytes >= 19 * 1024 * 1024` | WIRED | `processing_screen.dart` читает `args.isChunked` в `didChangeDependencies()` |
| `processing_screen.dart` | `ChunkedTranscriptionController` | `_chunkedController!.start(_file!)` | WIRED | Создаётся в `didChangeDependencies()`, слушатель `_onChunkedStateChange` |
| `ChunkedTranscriptionController` | `AudioChunkingService.split()` | `await _chunkingService.split(file.path)` | WIRED | В методе `start()` |
| `ChunkedTranscriptionController` | `GroqApiService.transcribeChunk()` | `_api.transcribeChunk(bytes, filename, apiKey)` | WIRED | В `_processChunk()` через `_withRetry()` |
| `processing_screen.dart` | `ChunkTile` | `ListView.builder` → `ChunkTile(state: chunks[i])` | WIRED | В `_buildChunkedBody()` при `ChunkedProcessing` |

---

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|-------------------|--------|
| `home_screen.dart` `_buildFilePreview` | `_metadata` | `AudioChunkingService().getMetadata()` → `FFprobeKit` | Да (реальный ffprobe в production; override в тестах) | FLOWING |
| `processing_screen.dart` `_buildChunkedBody` | `chunks` (ChunkedProcessing) | `ChunkedTranscriptionController._chunkStates` | Да — обновляется из `_updateChunkState()` | FLOWING |
| `processing_screen.dart` progressBar | `completedCount / totalCount` | `_completedCount` инкрементируется после каждого `ChunkDone` | Да | FLOWING |

---

### Behavioral Spot-Checks

Тесты запущены напрямую через `flutter test test/features/transcription/`:

| Behavior | Result | Status |
|----------|--------|--------|
| `AudioChunkingService.getMetadata()` парсит duration из ffprobe | 5000 мс → 5.0 сек | PASS |
| Null/невалидный duration → `InternalException` | Бросает InternalException | PASS |
| `AudioChunkingService.split()` → отсортированный список чанков | 2 файла chunk_000/001 | PASS |
| Retry: NetworkException на первом вызове → второй успешен | calls=2, ChunkedSuccess | PASS |
| AuthException → не ретраится | calls=1, ChunkedError(retryable=false) | PASS |
| Параллельность ≤ maxConcurrent=2 при 5 чанках | maxObserved ≤ 2 | PASS |
| Таймкоды: chunk0 → [00:00:00], chunk1 offset=1200s → [00:20:00] | text contains [00:20:00] | PASS |
| Cleanup: tmp-чанки удалены после success | all.deleted == true | PASS |
| Сценарий 1: 2 чанка happy path, ChunkedSuccess с таймкодами | [00:00:00] + [00:20:00] | PASS |
| Сценарий 2: retry после NetworkException | calls=2, ChunkedSuccess | PASS |
| Сценарий 3: 3 провальных попытки → ChunkedError | calls=3, retryable=true | PASS |
| Сценарий 4: AuthException + cleanup обоих файлов | deleted=true, retryable=false | PASS |

**Итог:** 16/16 тестов PASS

---

### Requirements Coverage

| Requirement | Description | Status | Evidence |
|-------------|-------------|--------|----------|
| ffprobe метаданные до старта | Имя, длительность, размер из ffprobe | SATISFIED | `audio_metadata.dart`, `audio_chunking_service.dart`, `home_screen._loadMetadata()` |
| Auto-chunking ≥ 19 МБ | ffmpeg сегментация, без ручных действий | SATISFIED | `ProcessingArgs.isChunked`, `AudioChunkingService.split()` |
| Параллельные запросы + UI прогресса | Процент + статус каждого чанка | SATISFIED | `_Semaphore`, `Future.wait()`, `ChunkTile`, `LinearProgressIndicator` |
| Retry с exponential backoff | NetworkException + 524 | SATISFIED | `_withRetry()` в контроллере, NetworkException покрывает 524 |
| Сборка с таймкодами + cleanup | offset = index * chunkDuration | SATISFIED | `_assembleResult()`, блок `finally` удаляет чанки |

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|---------|--------|
| `lib/ui/screens/home_screen.dart` | 243 | Устаревший текст `'до 19 МБ'` в empty state | WARNING | Вводит пользователя в заблуждение: ограничение 19 МБ снято в Phase 2, но подсказка осталась. Не блокирует функционал. |

Маркеры TBD/FIXME/XXX в ключевых файлах Phase 2: не обнаружено.

---

### Human Verification Required

#### 1. Chunked-режим на реальном устройстве Android

**Test:** Выбрать аудиофайл > 19 МБ (например, лекция 1 час, ~150 МБ mp3) на Android-устройстве. Нажать «Транскрибировать».
**Expected:** Экран обработки показывает список плиток чанков (ChunkTile) и прогресс-бар. Плитки поочерёдно переходят из "Ожидает" → "Отправляется..." → "Готов". Прогресс обновляется реально.
**Why human:** Логика переключения на chunked-режим основана на `sizeBytes >= 19 * 1024 * 1024` — без реального файла на устройстве не проверить. ffmpeg и ffprobe недоступны в тестовой среде.

#### 2. Отображение длительности из ffprobe

**Test:** Выбрать аудиофайл на HomeScreen. Наблюдать карточку файла.
**Expected:** В подстроке карточки появляется форматированная длительность вида `145.2 МБ · 1:23:45` (или `23:45` для коротких). На время загрузки метаданных должен быть виден CircularProgressIndicator размером 12x12.
**Why human:** ffprobe вызывается через `ffmpeg_kit_flutter_new`, который требует Android-среды. В тестах используется probeOverride.

#### 3. Текст-подсказка в empty state требует решения

**Test:** Открыть HomeScreen до выбора файла. Прочитать подсказку под иконкой загрузки.
**Expected (текущее):** `'mp3, wav, m4a, ogg, flac · до 19 МБ'`
**Проблема:** `file_validator.dart` явно снял ограничение 19 МБ. Подсказка вводит пользователя в заблуждение.
**Варианты решения:**
- Исправить на `'mp3, wav, m4a, ogg, flac · любой размер'`
- Или убрать часть `'· до 19 МБ'` полностью
**Why human:** Решение — продуктовое. Не блокирует технический функционал, но снижает UX.

---

### Gaps Summary

Техническая реализация полностью выполнена. Все 5 критериев успеха верифицированы через статический анализ кода и прохождение 16/16 тестов. Единственная выявленная проблема — устаревший текст-подсказка `'до 19 МБ'` в empty state HomeScreen (строка 243) — является UX-несоответствием, не блокирующим функционал.

Человеческая верификация необходима для:
1. Подтверждения работы chunked-пайплайна на реальном Android-устройстве с файлом > 19 МБ
2. Проверки отображения длительности из ffprobe в реальной среде
3. Принятия решения по тексту-подсказке

---

_Verified: 2026-05-17T12:00:00Z_
_Verifier: Claude (gsd-verifier)_
