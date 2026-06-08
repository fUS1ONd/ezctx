# Интеграция Deepgram nova-3 — дизайн

**Дата:** 2026-06-08
**Статус:** дизайн согласован, ожидает планирования (планирование — отдельной сессией)
**Ветка:** `feat/deepgram-nova3`

## Контекст и цель

Сейчас ezctx транскрибирует аудио только через **Groq Whisper API**. Пайплайн:
нормализация в `mp3 32k/16kHz/mono` → чанкинг ≤ 19 MB (порог 4920 c) → параллельная
отправка через пул ключей → сборка текста с таймкодами `[HH:MM:SS]`.

Цель — добавить второй движок распознавания, **Deepgram nova-3**, не ломая текущий
Whisper-путь. Решение опирается на собственное исследование
(`/root/projects/whisper-bitrate-research`, см. `results/REPORT.md` и
`DEEPGRAM_NOVA3_API.md`).

### Ключевые выводы исследования, влияющие на дизайн

- **nova-3 нечувствителен к битрейту/кодеку** — даже `mp3 32k ≈ lossless`. Можно жать
  агрессивно ради трафика.
- Текущий формат ezctx (`mp3 32k`) — **худший угол матрицы** для Whisper. При том же
  размере `opus 48k` даёт качество уровня `mp3 128k` (CER turbo: `mp3 32k = 12.35%` →
  `opus 48k ≈ 5%`).
- У nova-3 есть таймкоды (`words`/`paragraphs`/`utterances`), и автодетект языка
  (`detect_language=true`) — прямой аналог `auto` у Whisper.
- Все языки текущего enum приложения (`ru, uk, zh, ar, ko, ja, de, fr, es, en`)
  поддерживаются nova-3.

## Решения (согласованы)

1. **Стратегия: два провайдера, ручной выбор.** Whisper остаётся, Deepgram добавляется.
   Пользователь выбирает движок в настройках. Авто-роутинг по предмету **не делаем**.
2. **Чанкинг как у Whisper.** Единый пайплайн нарезки и сборки таймкодов для обоих
   провайдеров. Максимум переиспользования кода.
3. **Нормализация: `opus 48k/16kHz/mono` единым форматом** для обоих провайдеров.
   Контейнер `.ogg`, MIME `audio/ogg`.
4. **Пул ключей Deepgram** (ключи от **разных аккаунтов** → разные проекты → суммируются
   $200-кредиты и конкурентность). Обобщаем существующий пул.
5. **Архитектура — подход A:** интерфейс `TranscriptionProvider` + обобщённый
   провайдеро-независимый контроллер и пул.

### Экономика (справочно)

Deepgram биллит по **длительности аудио** (посекундно), **не** по размеру файла —
битрейт/кодек на стоимость не влияют. При ставке ~$0.0052/мин (русский pre-recorded):
$200 ≈ **~640 часов на аккаунт** (~425 лекций по 1.5 ч). Пул из N аккаунтов → ~640×N ч.

## Архитектура

```
┌─────────────────────────────────────────────────────────┐
│ UI: выбор Модель→Провайдер, выбор языка,                  │
│     раздельные пулы ключей Groq / Deepgram                │
│     (визуальный дизайн — ОТДЕЛЬНАЯ UI-фаза)               │
└───────────────────────────┬─────────────────────────────┘
                            │ TranscriptionOptions { model, language }
                            ▼
┌─────────────────────────────────────────────────────────┐
│ ChunkedTranscriptionController (провайдеро-независимый)   │
│  split → семафор → retry → assembleResult                 │
└───────┬──────────────────────────────────┬──────────────┘
        │ KeyPool (обобщён)                 │ TranscriptionProvider (интерфейс)
        │  политика блокировки по           │  ├ GroqProvider     (multipart, verbose_json)
        │  провайдеру (429/402/504)         │  └ DeepgramProvider (raw bytes, channels[].paragraphs)
        ▼                                   ▼
   secure storage:                     ffmpeg: нормализация opus 48k/16k/mono
   groq_api_keys_v1 /                  + чанкинг (.ogg, порог ~3240 c)
   deepgram_api_keys_v1
```

### Границы модулей

- **`TranscriptionProvider`** (новый интерфейс) — единственное, что знает специфику API:
  URL, формат тела (multipart vs raw), MIME, параметры запроса, парсинг ответа в общий
  `TranscriptionResult`, маппинг HTTP-кодов в нормализованные исключения, политику
  конкурентности.
  - `GroqProvider` — рефактор текущего `GroqApiService`.
  - `DeepgramProvider` — новый.
- **`KeyPool`** (обобщённый из `GroqKeyPool`) — round-robin + блокировки; провайдер задаёт
  трактовку ошибок.
- **`ChunkedTranscriptionController`, `AudioChunkingService`, `_assembleResult`** —
  **общие, провайдеро-независимые**, не меняются по сути.
- **`AudioNormalizationService`** — переводится на opus 48k (общий формат).

## Модель данных

```dart
enum TranscriptionProviderId { groq, deepgram }

// заменяет WhisperModel; модель привязана к провайдеру
enum TranscriptionModel {
  whisperLargeV3 (TranscriptionProviderId.groq,     'whisper-large-v3'),
  whisperTurbo   (TranscriptionProviderId.groq,     'whisper-large-v3-turbo'),
  nova3          (TranscriptionProviderId.deepgram, 'nova-3');
  // поля: provider, apiValue
}

// провайдер выводится из model.provider — отдельного поля нет
class TranscriptionOptions { TranscriptionModel model; TranscriptionLanguage language; }
```

**Язык — общий enum, маппинг внутри провайдера:**

| `TranscriptionLanguage` | GroqProvider | DeepgramProvider |
|---|---|---|
| `auto` | не передавать `language` | `detect_language=true` |
| `ru`/`en`/… | `language=<iso>` | `language=<iso>` |

Весь текущий enum поддержан обоими провайдерами — fallback для «неподдерживаемого языка»
не нужен.

**Миграция хранилища:** старый `transcription_options_v1` (`model:"largeV3"`) грузится без
краша; `fromJson` мапит старые значения в новую модель (текущий `orElse` уже защищает).

## Формат запроса/ответа Deepgram

**Запрос** (raw bytes, не multipart):
```
POST https://api.deepgram.com/v1/listen?model=nova-3&smart_format=true&paragraphs=true&<lang>
Authorization: Token <KEY>
Content-Type: audio/ogg
Body: <сырые байты чанка>
```
- `smart_format=true` — пунктуация/заглавные/числа → читаемый txt (core value продукта).
- `paragraphs=true` — абзацы с таймкодами для сборки `[HH:MM:SS]`.
- `<lang>`: `detect_language=true` (auto) либо `language=<iso>`.
- `keyterm` — **не используем** в этой итерации (YAGNI; оставить хук на будущее).

**Парсинг ответа** → общий `TranscriptionResult`:
```
results.channels[0].alternatives[0]:
  .transcript               → плоский текст
  .paragraphs.paragraphs[]  → { start, end, sentences[] } → TranscriptionSegment{start,end,text}
  .words[]                  → fallback, если paragraphs пуст
```
`_assembleResult` применяет `chunkIndex*chunkDuration + segment.start` без изменений.

## Нормализация и чанкинг

- **Нормализация:** `ffmpeg -c:a libopus -b:a 48k -ac 1 -ar 16000` → `.ogg`.
  Требует наличия **libopus** в сборке `ffmpeg_kit_flutter_new` — проверить при
  планировании; если нет, fallback-вариант — `mp3 64k`.
- **Порог чанкинга:** пересчёт под opus 48k. По номиналу `48 kbps = 6000 B/s`:
  под ≤ 18.5 MB → `kChunkThresholdSeconds ≈ 3240 c (~54 мин)`. opus VBR обычно даёт
  меньше номинала, порог консервативен. Лимит важен только для Groq (Deepgram до 2 ГБ),
  но порог берём по жёсткому (Groq), т.к. пайплайн единый.
- Точки правки под смену контейнера: расширение чанков `.ogg` (сейчас `chunk_%03d.mp3`),
  MIME в провайдере (Groq сейчас хардкодит `audio/mpeg`).

## Обработка ошибок и пул ключей

**Нормализованные исключения** (провайдер маппит свои HTTP-коды):

| Ситуация | Groq | Deepgram | Исключение | Реакция пула |
|---|---|---|---|---|
| Невалидный ключ | 401 | 401 | `AuthException` | стоп, не ретраить |
| Лимит/конкурентность (временно) | 429/503 | 429 | `RateLimitException(retryAfter)` | блок ключа на N сек |
| Кредиты кончились (надолго) | — | 402 | `KeyExhaustedException` | вывести ключ из ротации |
| Таймаут/5xx | 5xx | 504/5xx | `NetworkException` | ретрай с задержкой |

**Изменения в пуле** (`GroqKeyPool` → `KeyPool`):
- Новый статус `ExhaustedKeyStatus` (в дополнение к `Active`/`Blocked`).
- `reportExhausted(key)` — постоянный вывод ключа (без таймера разблокировки).
- `acquireKey`/`aliveKeyCount` исключают exhausted; все исчерпаны → `AllKeysBlockedException`
  с сообщением про кредиты Deepgram.
- Groq никогда не вернёт 402 → `GroqProvider` не бросает `KeyExhaustedException`; один пул
  обслуживает оба провайдера.

**Политика конкурентности — часть провайдера** (`concurrencyFor(aliveKeyCount) → int`):

| Провайдер | Политика | 1 ключ | 3 ключа |
|---|---|---|---|
| Groq | `aliveKeyCount.clamp(1, 5)` — поток на ключ | 1 | 3 |
| Deepgram | `aliveKeyCount > 0 ? 5 : 0` — ключ тянет 50 | **5** | 5 |

(`kMaxConcurrentChunks = 5` сохраняется.)

**504** маловероятен (чанк ≤ 54 мин, nova-3 быстрая), трактуется как ретраибельная
сетевая ошибка.

## UI (функциональный контракт)

Конкретный визуальный дизайн и UX-компоновка — **отдельная UI-фаза** с UI/UX-агентом,
который соблюдёт дизайн-систему проекта (liquid glass: `glass_card`, `design_tokens`,
golden-тесты) и отдаст на разработку. Здесь фиксируется только что пользователь должен мочь:

- Выбрать модель транскрибации; провайдер выводится из модели (Whisper Large v3 / Whisper
  Turbo → Groq; Nova-3 → Deepgram).
- Выбрать язык — общий выбор, работает для обоих провайдеров (включая «Авто»).
- Управлять **двумя раздельными наборами ключей** (Groq и Deepgram): добавить/удалить/статус.
- Видеть статусы ключей: активен / временно заблокирован (таймер) / **исчерпан** (новый,
  только Deepgram).
- Видеть готовность: «подключено» — по наличию живого ключа в пуле **выбранного** провайдера.
  При выборе Nova-3 без ключей Deepgram → подсказка добавить ключ Deepgram.

**Под капотом (связка DI):**
- Раздельное хранение `groq_api_keys_v1` / `deepgram_api_keys_v1`; `SecureStorageService`/
  `ApiKeyRepository` параметризуются namespace провайдера.
- Два пула: `groqKeyPoolProvider` + `deepgramKeyPoolProvider`.
- На `/processing` контроллер получает пару `provider+pool` по `options.model.provider`.
- `ChunkedMissingKey` проверяет пул выбранного провайдера.

**YAGNI:** keyterm UI, выбор `smart_format`/формата, счётчик расхода кредитов — не делаем.

## Тестирование

Два этапа:

1. **В фазах реализации** — базовые тесты пишутся вместе с кодом (планка проекта):
   - `DeepgramProvider`: парсинг ответа по JSON-фикстурам nova-3 (`paragraphs`/`words` →
     `TranscriptionSegment`); построение raw-запроса (URL/параметры/заголовки/`audio/ogg`);
     маппинг кодов `401→Auth`, `402→KeyExhausted`, `429→RateLimit`, `504→Network`
     (`MockClient`).
   - Обобщённый `KeyPool`: `reportExhausted`, исключение exhausted из ротации, все
     исчерпаны → `AllKeysBlockedException`; регрессия существующих Groq-тестов пула.
   - Политика `concurrencyFor`: Groq `1→1`/`3→3`, Deepgram `1→5`.
   - Контроллер с mock-провайдером: чанкинг/сборка/таймкоды/retry одинаковы для обоих.
   - Миграция `TranscriptionOptions` из старого хранилища.
   - Нормализация opus: команда ffmpeg, расширение `.ogg`/MIME; пересчитанный порог.
   - Регрессия: весь существующий зелёный Whisper-набор остаётся зелёным.

2. **Отдельная фаза валидации тестов** (`gsd-validate-phase` / Nyquist) — ревью
   осмысленности тест-кейсов (поведение, не реализация) + систематический разбор граничных
   случаев. Вход — список ниже.

### Граничные случаи (затравка для фазы валидации)

**Парсинг ответа Deepgram:**
- Пустой `transcript` (тишина/музыка) — `channels`/`alternatives` пустые.
- `paragraphs` отсутствует → fallback на `words` → fallback на плоский текст без таймкодов.
- Подтвердить, что `start`/`end` **0-based относительно начала чанка** (иначе offset чанка
  сложится дважды).
- `detect_language` вернул разные языки для разных чанков (code-switching) — что в итоговый
  `language`.

**Чанкинг / нормализация:**
- opus VBR дал чанк тяжелее порога (>19 или >25 MB) — нужен запас/проверка размера.
- Сегментация `.ogg`/opus через `-f segment -c:a copy` — корректность границ по ogg-страницам.
- Очень короткий файл (n=1, shortcircuit).

**Пул ключей / ошибки:**
- `402` на части ключей в середине обработки → продолжение на оставшихся.
- Все Deepgram-ключи исчерпаны в середине → сообщение + судьба частичного результата.
- Выбран Deepgram без DG-ключей (есть только Groq) → `ChunkedMissingKey` по нужному пулу.
- Сеть рвётся на одном чанке из N → retry, остальные не страдают.

## Точки изменения в коде (ориентир для планирования)

- `lib/features/transcription/transcription_options.dart` — новые enum'ы, миграция.
- `lib/features/transcription/groq_api_service.dart` → `GroqProvider` за интерфейсом.
- `lib/features/transcription/deepgram_provider.dart` — новый.
- `lib/features/transcription/transcription_provider.dart` — новый интерфейс.
- `lib/features/transcription/groq_key_pool.dart` → обобщённый `KeyPool` + `ExhaustedKeyStatus`.
- `lib/features/transcription/chunked_transcription_controller.dart` — провайдеро-независимость,
  ветка `KeyExhaustedException`, `concurrencyFor`.
- `lib/features/transcription/audio_normalization_service.dart` — opus 48k/.ogg.
- `lib/features/transcription/audio_chunking_service.dart` — `.ogg`, пересчёт порога.
- `lib/core/constants/app_constants.dart` — `kChunkThresholdSeconds`, Deepgram URL, storage-ключи.
- `lib/core/error/app_exception.dart` — `KeyExhaustedException`.
- `lib/core/storage/secure_storage_service.dart`, `lib/features/settings/api_key_repository.dart`
  — namespace провайдера.
- `lib/core/providers/*` — второй пул, проводка провайдера.
- UI (`settings_screen`, `api_keys_screen`, `key_status_tile`, …) — **отдельная UI-фаза**.

## Явные не-цели (этой итерации)

- Авто-роутинг по предмету (мат/проза).
- Keyterm Prompting.
- Конфигурируемый `smart_format`/выбор формата вывода.
- Счётчик/индикация расхода кредитов Deepgram.
- Async-режим Deepgram с `callback` (требует публичный URL — невозможно без сервера).
