# Phase 09 Context — Equal Chunk Distribution

## Источник

Дизайн утверждён в брейншторминге (сессия 2026-05-18).

## Проблема

`AudioChunkingService.split()` использует фиксированный шаг `kChunkDurationSeconds = 4500` (75 мин ≈ 17.6 MB).
При параллельной обработке время транскрибации = время самого долгого чанка.
Аудио 76 мин → 75 мин + 1 мин: bottleneck 75 мин, хотя достаточно 38 мин.

## Решение (Подход A — утверждён)

Вычислять `optimalDuration = totalDuration / ceil(totalDuration / kChunkThresholdSeconds)`.

Все чанки одинаковые, ни один не является bottleneck'ом.

## Ключевые решения

1. **Алгоритм:** `N = ceil(totalDuration / kChunkThresholdSeconds)`, `optimalDuration = totalDuration / N`
2. **Новый порог:** `kChunkThresholdSeconds = 4920` (82 мин ≈ 18.7 MB при 32 kbps) — было 4500 (75 мин ≈ 17.6 MB)
3. **Удалить:** `kChunkDurationSeconds = 4500.0` — заменяется динамическим вычислением
4. **Сигнатура:** `split(String filePath, double totalDurationSeconds, {String? outputDir})`
5. **Таймкоды:** `offset = index * optimalDuration` — `ChunkedTranscriptionController` уже работает так, изменений не требует
6. **isChunked порог:** `kChunkThresholdSeconds` используется и для определения isChunked — при поднятии порога короткие лекции (~76 мин) теперь могут пройти как single-shot, экономя запрос к Groq
7. **UI:** изменений нет

## Математика

```
32 kbps = 4000 bytes/sec
19 MB = 19 × 1024 × 1024 / 4000 = 4981 сек ≈ 83 мин (теоретический max)
kChunkThresholdSeconds = 4920 (82 мин = 18.7 MB) — с запасом на MP3-фреймы
```

## Примеры

| Длительность | N | optimalDuration | Старое (порог 75 мин) |
|---|---|---|---|
| 70 мин (4200s) | single-shot | — | single-shot |
| 76 мин (4560s) | single-shot | — | 75 + 1 мин (2 запроса!) |
| 84 мин (5040s) | 2 | 42 мин | 75 + 9 мин |
| 150 мин (9000s) | 2 | 75 мин | 75 + 75 мин |
| 165 мин (9900s) | 3 | 55 мин | 75 + 75 + 15 мин |

## Затронутые файлы

- `lib/core/constants/app_constants.dart` — обновить `kChunkThresholdSeconds`, удалить `kChunkDurationSeconds`
- `lib/features/transcription/audio_chunking_service.dart` — новая логика `split()`
- `test/features/transcription/audio_chunking_service_test.dart` — обновить тесты
- Проверить: `chunked_transcription_controller.dart` — должен работать без изменений (offset = index * chunkDuration уже передаётся из split)
