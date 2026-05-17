# Phase 3 Context: Audio Normalization (Pre-Transcription)

## Phase Goal

Любой аудиоформат конвертируется в 32 kbps / 16 kHz / Mono mp3 перед чанкованием.
isChunked определяется по длительности нормализованного файла.
UI показывает «Подготовка аудио…» во время конвертации.

## Problem Statement

Текущий баг Phase 2: 35 MB OGG-файл длительностью < 20 мин чанкуется в 1 чанк (сегментация по времени 1200s), но исходный размер > 19 MB → isChunked=true → отправляется как 1 чанк > лимита Groq → ошибка.

Причина: ffmpeg не умеет делить по размеру файла, только по времени. При смешанных форматах (OGG, M4A, WAV высокого битрейта) невозможно заранее знать размер выходного чанка.

Решение: нормализовать ВСЕГДА в 32 kbps / 16 kHz / Mono mp3. Тогда:
- 1 мин нормализованного аудио = ~240 KB (32kbps * 60s / 8)
- Порог для isChunked: ~80 мин (≈19 MB)
- Размер чанка: фиксированная длительность, например 75 мин (≈17.6 MB) → гарантированно < 19 MB

## Key Decisions

### D1: Нормализовывать всегда, не только при chunked path
**Решение:** Нормализация выполняется для ЛЮБОГО файла, до определения isChunked.
**Причина:** isChunked должен считаться по нормализованному файлу, иначе логика ненадёжна.

### D2: Целевой формат — 32 kbps / 16 kHz / Mono mp3
**Решение:** `-b:a 32k -ac 1 -ar 16000 -codec:a libmp3lame`
**Причина:** Минимальный битрейт, достаточный для распознавания речи Whisper; 16 kHz — нативная частота Whisper; Mono — половина размера стерео; mp3 — универсальный формат, поддерживаемый Groq.
**Расчёт:** 1 мин = 32*60/8 = 240 KB → 19 MB = ~80 мин; чанки по 75 мин = ~17.6 MB ✓

### D3: isChunked переходит на длительность нормализованного файла
**Решение:** `isChunked = normalizedDurationSeconds > kChunkThresholdSeconds`
где `kChunkThresholdSeconds = 75 * 60 = 4500` (75 мин)
**Причина:** После нормализации размер предсказуем, делить по времени → безопасно.

### D4: UI показывает прогресс нормализации
**Решение:** Добавить состояние `normalizing` в ProcessingScreen с текстом «Подготовка аудио…».
**Причина:** Конвертация часового файла может занять 30–90 сек на слабом телефоне; без индикатора пользователь думает, что приложение зависло.

### D5: Промежуточный нормализованный файл удаляется после транскрибации
**Решение:** Нормализованный tmp-файл удаляется вместе с чанками по завершении.

## Architecture

```
FilePickerService → ProcessingArgs → ProcessingScreen
                                           │
                                    [normalizing state]
                                           │
                                    AudioNormalizationService
                                    ffmpeg: -b:a 32k -ac 1 -ar 16000 -codec:a libmp3lame
                                           │
                                    NormalizedAudioFile (path, durationSeconds)
                                           │
                                    isChunked? (durationSeconds > 4500)
                                    ┌──────┴──────┐
                               single-shot    chunked path
                              GroqApiService  AudioChunkingService
```

## Files to Touch

### New files
- `lib/features/transcription/audio_normalization_service.dart` — ffmpeg-конвертация в 32k mono mp3
- `lib/features/transcription/normalized_audio_file.dart` — value object (path, durationSeconds)

### Modified files
- `lib/features/transcription/audio_chunking_service.dart` — убрать конвертацию из split(); чанковать уже нормализованный mp3
- `lib/features/transcription/processing_args.dart` — убрать `isChunked` по sizeBytes; добавить по длительности нормализованного
- `lib/ui/screens/processing_screen.dart` — добавить состояние `normalizing`, запускать NormalizationService первым
- `lib/core/constants/app_constants.dart` — добавить `kChunkThresholdSeconds`, `kNormalizedBitrate`

### Test files
- `test/features/transcription/audio_normalization_service_test.dart`
- обновить `test/features/transcription/audio_chunking_service_test.dart`

## Supported Input Formats (Groq-compatible)
mp3, mp4, mpeg, mpga, m4a, wav, webm, ogg, flac

## Out of Scope
- Прогресс-бар в % для нормализации (ffmpeg не даёт прогресс без -progress флага в kit)
- Сохранение нормализованного файла для повторного использования
