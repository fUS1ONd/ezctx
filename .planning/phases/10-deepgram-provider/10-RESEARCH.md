# Фаза 10: DeepgramProvider + DI-проводка — Research

**Researched:** 2026-06-10
**Domain:** Deepgram nova-3 REST API + Flutter/Dart DI + мульти-провайдерная архитектура
**Confidence:** HIGH

---

## Summary

Фазы 07/08/09 уже реализованы. `TranscriptionProvider` (интерфейс), `KeyPool` (с `ExhaustedKeyStatus`/`reportExhausted`), `KeyExhaustedException`, `TranscriptionProviderId.deepgram`, `TranscriptionModel.nova3` — всё уже существует в кодовой базе. Фаза 10 дописывает конкретные отсутствующие части: реализацию `DeepgramProvider`, namespace-параметризацию `SecureStorageService`/`ApiKeyRepository`, второй пул в DI, выбор `provider+pool` по `options.model.provider` в `ProcessingScreen`.

Deepgram nova-3 pre-recorded API принимает **raw bytes** тела запроса (не multipart) с `Content-Type: audio/ogg`. Структура ответа содержит `results.channels[0].alternatives[0]` с полями `transcript`, `paragraphs.paragraphs[]` (nested: каждый параграф → `sentences[]` с `{text, start, end}`), `words[]`. `smart_format=true` и `paragraphs=true` доступны без ограничений по тарифному плану. Код ошибок: 401→Auth, 402→KeyExhausted, 429→RateLimit, 504/5xx→Network — совпадают с дизайн-документом.

Ключевое открытие: `SecureStorageServiceImpl` сейчас **хардкодит** `_storageKey = AppConstants.storageKeyApiKeys` (`'groq_api_keys_v1'`), а `ApiKeyRepository` не параметризован по namespace. Оба класса нужно расширить под dual-namespace схему. `main.dart` сейчас читает только один пул (`groqKeyPool`) и переопределяет только `groqKeyPoolProvider` — нужно добавить bootstrap второго пула `deepgramKeyPool`.

**Primary recommendation:** Реализовать `DeepgramProvider` зеркально `GroqProvider` (raw bytes вместо multipart, парсинг paragraphs), параметризовать storage namespace, добавить `deepgramKeyPoolProvider`, обновить `ProcessingScreen` для выбора пула по `options.model.provider`.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| HTTP-запрос к Deepgram API | Feature / TranscriptionProvider | — | Специфика провайдера инкапсулирована в `DeepgramProvider` |
| Парсинг paragraphs → TranscriptionSegment | Feature / TranscriptionProvider | — | Провайдеро-специфичный маппинг, не меняет общий `TranscriptionResult` |
| Пул ключей Deepgram | Feature / KeyPool | — | Тот же `KeyPool`, другой инстанс |
| Хранение ключей Deepgram | Core / SecureStorage | — | Namespace `deepgram_api_keys_v1` в том же `flutter_secure_storage` |
| Выбор provider+pool по модели | UI Screen / ProcessingScreen | Core / DI | Маршрутизация при старте обработки |
| Сборка таймкодов | Feature / ChunkedTranscriptionController | — | Провайдеро-независима, не меняется |
| Нормализация/чанкинг | Feature / AudioNormalizationService + ChunkingService | — | Уже opus/.ogg, не меняется |

---

## Существующий контракт (phases 07–09)

### TranscriptionProvider (интерфейс) [VERIFIED: lib/features/transcription/transcription_provider.dart]

```dart
abstract interface class TranscriptionProvider {
  Future<TranscriptionResult> transcribeChunk({
    required List<int> bytes,
    required String filename,
    required String apiKey,
    TranscriptionOptions options,
  });

  int concurrencyFor(int aliveKeyCount);
  TranscriptionProviderId get id;
}
```

`DeepgramProvider` реализует все три члена. Параметр `filename` используется Groq для multipart, Deepgram его игнорирует (raw bytes). Контракт не меняется.

### TranscriptionModel / TranscriptionProviderId [VERIFIED: lib/features/transcription/transcription_options.dart]

```dart
enum TranscriptionProviderId { groq, deepgram }

enum TranscriptionModel {
  whisperLargeV3(TranscriptionProviderId.groq, 'whisper-large-v3'),
  whisperTurbo(TranscriptionProviderId.groq, 'whisper-large-v3-turbo'),
  nova3(TranscriptionProviderId.deepgram, 'nova-3');

  const TranscriptionModel(this.provider, this.apiValue);
  final TranscriptionProviderId provider;
  final String apiValue;
}
```

**Вывод:** `TranscriptionModel.nova3` и `TranscriptionProviderId.deepgram` уже существуют. Enum расширять НЕ нужно.

### KeyPool (обобщённый) [VERIFIED: lib/features/transcription/key_pool.dart]

Уже содержит `ExhaustedKeyStatus`, `reportExhausted(key)`, логику `_failWaitersIfPoolDead()`. Конструктор: `KeyPool({List<String> initialKeys = const []})`. Единственное что нужно — создать второй инстанс для Deepgram.

### Нормализованные исключения [VERIFIED: lib/core/error/app_exception.dart]

| Класс | Конструктор | Использование |
|-------|-------------|---------------|
| `AuthException(message)` | `const AuthException(String)` | 401 |
| `KeyExhaustedException([message])` | `const KeyExhaustedException([String])` | 402 Deepgram |
| `RateLimitException(message, {retryAfterSeconds})` | `const RateLimitException(String, {int retryAfterSeconds = 60})` | 429 |
| `NetworkException(message)` | `const NetworkException(String)` | 504/5xx |
| `AllKeysBlockedException([message])` | `const AllKeysBlockedException([String])` | пул опустел |

**Все классы уже существуют.** `app_exception.dart` расширять не нужно — только использовать.

### ChunkedTranscriptionController [VERIFIED: lib/features/transcription/chunked_transcription_controller.dart]

Уже провайдеро-независим: принимает `TranscriptionProvider` и `KeyPool` через конструктор. Уже обрабатывает `KeyExhaustedException` (вызывает `pool.reportExhausted(key)`). Изменять контроллер не нужно.

---

## Точки изменения и создания файлов

### 1. НОВЫЙ: `lib/features/transcription/deepgram_provider.dart`

**Запрос (raw bytes, не multipart):** [VERIFIED: developers.deepgram.com/docs/paragraphs + developers.deepgram.com/reference/speech-to-text/listen-pre-recorded]

```
POST https://api.deepgram.com/v1/listen?model=nova-3&smart_format=true&paragraphs=true&<lang>
Authorization: Token <KEY>
Content-Type: audio/ogg
Body: <raw chunk bytes>
```

- Язык: если `TranscriptionLanguage.auto` → `detect_language=true`; иначе → `language=${options.language.isoCode}`
- Параметр `keyterm` — не используем

**Парсинг ответа Deepgram:** [VERIFIED: developers.deepgram.com/docs/paragraphs]

Точная вложенная структура JSON:
```
results.channels[0].alternatives[0]
  .transcript                 → String (плоский текст — для TranscriptionResult.text если нет segments)
  .paragraphs
    .transcript               → String (текст с переносами строк)
    .paragraphs[]             → список параграфов, каждый:
        .sentences[]          → список предложений, каждое:
            .text             → String
            .start            → double (секунды от начала ЧАНКА)
            .end              → double
        .num_words            → int
        .start                → double
        .end                  → double
  .words[]                    → список слов (fallback), каждое:
      .word                   → String
      .start                  → double
      .end                    → double
```

**Маппинг: `paragraphs.paragraphs[].sentences[]` → `TranscriptionSegment{start, end, text}`:**
Каждый элемент `sentences[]` маппируется в один `TranscriptionSegment`. `start`/`end` — 0-based относительно начала чанка (не файла). `_assembleResult` добавляет `chunkOffset` — двойного сложения нет.

**Fallback-цепочка:**
1. `paragraphs?.paragraphs?.isNotEmpty == true` → маппинг через `sentences[]`
2. `paragraphs` пуст → fallback на `words[]` → каждое слово как сегмент (или объединить в один)
3. `words` пусты → использовать плоский `.transcript` без таймкодов

**Конкурентность:** `concurrencyFor(aliveKeyCount) => aliveKeyCount > 0 ? 5 : 0`

**Маппинг HTTP-кодов:** [VERIFIED: developers.deepgram.com/docs/errors]

| Код | Исключение |
|-----|-----------|
| 200 | — (успех) |
| 401 | `AuthException` |
| 402 | `KeyExhaustedException` (Insufficient credits) |
| 429 | `RateLimitException` (заголовок `retry-after` если есть; fallback 60 с) |
| 504 / 5xx | `NetworkException` |

**Структура класса (зеркалит GroqProvider):**

```dart
class DeepgramProvider implements TranscriptionProvider {
  DeepgramProvider({http.Client Function()? clientFactory})
      : _clientFactory = clientFactory ?? (() => http.Client());

  final http.Client Function() _clientFactory;

  @override
  Future<TranscriptionResult> transcribeChunk({...}) async { ... }

  @override
  int concurrencyFor(int aliveKeyCount) => aliveKeyCount > 0 ? 5 : 0;

  @override
  TranscriptionProviderId get id => TranscriptionProviderId.deepgram;
}
```

### 2. ИЗМЕНЕНИЕ: `lib/core/storage/secure_storage_service.dart`

**Проблема:** `SecureStorageServiceImpl` хардкодит `_storageKey = AppConstants.storageKeyApiKeys` (`'groq_api_keys_v1'`). [VERIFIED: lib/core/storage/secure_storage_service.dart]

**Решение:** Параметризовать через конструктор:

```dart
class SecureStorageServiceImpl implements SecureStorageService {
  SecureStorageServiceImpl({
    FlutterSecureStorage? storage,
    String storageKey = AppConstants.storageKeyApiKeys, // обратная совместимость
  }) : _storage = storage ?? const FlutterSecureStorage(aOptions: AndroidOptions()),
       _storageKey = storageKey; // убрать static, сделать final

  final FlutterSecureStorage _storage;
  final String _storageKey; // было: static const _storageKey = ...
  ...
}
```

Groq-вариант вызывается без аргументов → поведение не меняется.

### 3. ИЗМЕНЕНИЕ: `lib/features/settings/api_key_repository.dart`

**Проблема:** `ApiKeyRepository` не параметризован по namespace. [VERIFIED: lib/features/settings/api_key_repository.dart]

**Решение:** Добавить необязательный параметр или сделать namespace явным. Два подхода:

**Вариант A** (рекомендуется): `ApiKeyRepository` остаётся без изменений — namespace идёт через `SecureStorageService`, который параметризуется при создании в DI:

```dart
// В repository_providers.dart:
final deepgramApiKeyRepoProvider = Provider<ApiKeyRepository>(
  (ref) => ApiKeyRepository(ref.watch(deepgramSecureStorageProvider)),
);
```

Создать отдельный `deepgramSecureStorageProvider` в `storage_providers.dart`, который передаёт `storageKey = AppConstants.storageKeyDeepgramApiKeys`.

### 4. ИЗМЕНЕНИЕ: `lib/core/constants/app_constants.dart`

Добавить:
```dart
// Deepgram API
static const String deepgramApiUrl = 'https://api.deepgram.com/v1/listen';

// Secure storage keys
static const String storageKeyDeepgramApiKeys = 'deepgram_api_keys_v1';
```

### 5. ИЗМЕНЕНИЕ: `lib/core/providers/storage_providers.dart`

Добавить:
```dart
final deepgramSecureStorageProvider = Provider<SecureStorageService>(
  (ref) => SecureStorageServiceImpl(
    storageKey: AppConstants.storageKeyDeepgramApiKeys,
  ),
);
```

### 6. ИЗМЕНЕНИЕ: `lib/core/providers/repository_providers.dart`

Добавить `deepgramApiKeyRepoProvider` и `deepgramApiKeysProvider`:

```dart
final deepgramApiKeyRepoProvider = Provider<ApiKeyRepository>(
  (ref) => ApiKeyRepository(ref.watch(deepgramSecureStorageProvider)),
);

final deepgramApiKeysProvider = FutureProvider<List<ApiKeyView>>((ref) async {
  return ref.watch(deepgramApiKeyRepoProvider).listKeys();
});
```

### 7. ИЗМЕНЕНИЕ: `lib/core/providers/service_providers.dart`

Добавить `deepgramKeyPoolProvider`:

```dart
final deepgramKeyPoolProvider = Provider<KeyPool>((ref) {
  throw UnimplementedError('deepgramKeyPoolProvider must be overridden in ProviderScope');
});
```

`transcriptionProviderProvider` заменить на функцию/family либо удалить — теперь провайдер выбирается в `ProcessingScreen` по `options.model.provider`. Или оставить `transcriptionProviderProvider` как Groq-default для обратной совместимости и добавить `deepgramTranscriptionProviderProvider`.

**Рекомендация:** убрать `transcriptionProviderProvider` из глобального DI, т.к. выбор провайдера динамический (по `options`). `ProcessingScreen` создаёт нужный провайдер сам через `ref.read(groqKeyPoolProvider)` / `ref.read(deepgramKeyPoolProvider)`.

### 8. ИЗМЕНЕНИЕ: `lib/main.dart`

Добавить bootstrap второго пула:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final bootstrap = ProviderContainer();
  final groqRawKeys = await bootstrap.read(apiKeyRepoProvider).listKeys();
  final deepgramRawKeys = await bootstrap.read(deepgramApiKeyRepoProvider).listKeys();
  bootstrap.dispose();

  final groqKeyPool = KeyPool(initialKeys: groqRawKeys.map((k) => k.raw).toList());
  final deepgramKeyPool = KeyPool(initialKeys: deepgramRawKeys.map((k) => k.raw).toList());

  runApp(
    ProviderScope(
      overrides: [
        groqKeyPoolProvider.overrideWithValue(groqKeyPool),
        deepgramKeyPoolProvider.overrideWithValue(deepgramKeyPool),
      ],
      child: const EzCtxApp(),
    ),
  );
}
```

### 9. ИЗМЕНЕНИЕ: `lib/ui/screens/processing_screen.dart`

**Сейчас:** хардкодит `groqKeyPoolProvider` и `transcriptionProviderProvider`. [VERIFIED: lib/ui/screens/processing_screen.dart строка 126-128]

**Нужно:** выбирать пул и провайдер по `options.model.provider`:

```dart
// Определяем пул и провайдер по выбранному провайдеру
final pool = _transcriptionOptions.model.provider == TranscriptionProviderId.deepgram
    ? ref.read(deepgramKeyPoolProvider)
    : ref.read(groqKeyPoolProvider);

final apiService = _transcriptionOptions.model.provider == TranscriptionProviderId.deepgram
    ? DeepgramProvider()
    : GroqProvider();
```

Также обновить сообщение `ChunkedMissingKey` — оно сейчас говорит "Добавьте API-ключ Groq", нужно динамизировать по провайдеру.

---

## Don't Hand-Roll

| Проблема | Не строить | Использовать | Почему |
|----------|-----------|--------------|--------|
| HTTP raw-body запрос | Кастомный HTTP клиент | `http.Client().post(uri, headers: ..., body: bytes)` | `http` пакет уже в зависимостях, поддерживает raw bytes |
| Маппинг JSON ответа | Ручной xml/string парсинг | `jsonDecode` + типизированный доступ | Стандартный подход проекта |
| Хранение ключей | Свой файл/SharedPreferences | `SecureStorageServiceImpl(storageKey: ...)` | Уже реализовано, только параметризовать |
| Пул ключей | Новый класс DeepgramKeyPool | `KeyPool(initialKeys: ...)` | `KeyPool` уже обобщён в фазе 09 |
| Ретрай/конкурентность | Кастомный retry в DeepgramProvider | `ChunkedTranscriptionController` | Уже реализован, провайдеро-независим |
| `retry-after` parsing | Копировать из `groq_api_service.dart` | Вынести `parseRetryAfterFromHeaders` в shared helper или продублировать | Deepgram тоже может вернуть `retry-after` заголовок |

**Важно про `parseRetryAfterFromHeaders`:** функция сейчас живёт в `groq_api_service.dart` как top-level. `DeepgramProvider` может либо дублировать логику (простой fallback на 60 с — Deepgram не документирует custom retry headers), либо плановик решит вынести в shared файл. Простейшее решение: в `DeepgramProvider` при 429 читать `retry-after` если есть, иначе fallback 60 с.

---

## Deepgram API — сводка верифицированных фактов

### Запрос [VERIFIED: developers.deepgram.com/docs/paragraphs]

```
POST https://api.deepgram.com/v1/listen
  ?model=nova-3
  &smart_format=true
  &paragraphs=true
  &detect_language=true          // если auto
  &language=ru                   // если явно задан
Authorization: Token <KEY>       // НЕ Bearer, именно Token
Content-Type: audio/ogg
Body: <raw bytes>
```

`smart_format=true` и `paragraphs=true` доступны всем аккаунтам, не требуют специального тарифа. [CITED: developers.deepgram.com/docs/paragraphs]

### Ответ — структура paragraphs [VERIFIED: developers.deepgram.com/docs/paragraphs]

```json
{
  "results": {
    "channels": [{
      "alternatives": [{
        "transcript": "flat text...",
        "words": [{"word": "...", "start": 0.5, "end": 0.9}],
        "paragraphs": {
          "transcript": "text with newlines...",
          "paragraphs": [
            {
              "sentences": [
                {"text": "sentence text.", "start": 0.33, "end": 3.77}
              ],
              "num_words": 64,
              "start": 0.33,
              "end": 32.07
            }
          ]
        }
      }],
      "detected_language": "ru"
    }]
  }
}
```

**Ключевое:** `start`/`end` в `sentences[]` — секунды от начала **чанка** (0-based). `_assembleResult` добавляет `chunkOffset`. Двойного прибавления нет.

**`detected_language`** находится на уровне `channels[0]`, не в `alternatives`. [VERIFIED: developers.deepgram.com/docs/language-detection]

### HTTP ошибки [VERIFIED: developers.deepgram.com/docs/errors]

| Код | Категория | Маппинг |
|-----|-----------|---------|
| 401 | Incorrect API key / Insufficient permissions | `AuthException` |
| 402 | Insufficient credits (Speech to Text) | `KeyExhaustedException` |
| 429 | Rate limit exceeded | `RateLimitException` |
| 504 | Gateway timeout | `NetworkException` |
| 5xx | Server error | `NetworkException` |

### Нормализация аудио (уже реализована в фазе 08) [VERIFIED: lib/features/transcription/audio_normalization_service.dart]

Opus 48k/16kHz/mono, контейнер `.ogg`, MIME `audio/ogg`. Deepgram принимает `audio/ogg` напрямую. Никаких изменений в нормализации не требуется.

---

## Архитектурные паттерны

### Паттерн: raw bytes HTTP POST (vs multipart в GroqProvider)

```dart
// Deepgram: raw bytes, не multipart
final uri = Uri.parse(AppConstants.deepgramApiUrl).replace(
  queryParameters: {
    'model': options.model.apiValue,   // 'nova-3'
    'smart_format': 'true',
    'paragraphs': 'true',
    if (options.language == TranscriptionLanguage.auto)
      'detect_language': 'true'
    else
      'language': options.language.isoCode,
  },
);

final response = await client.post(
  uri,
  headers: {
    'Authorization': 'Token $apiKey',
    'Content-Type': 'audio/ogg',
  },
  body: Uint8List.fromList(bytes),
).timeout(const Duration(minutes: 5));
```

### Паттерн: парсинг paragraphs → TranscriptionSegment

```dart
TranscriptionResult _parseResponse(Map<String, dynamic> json) {
  final channel = (json['results']['channels'] as List).first as Map<String, dynamic>;
  final alt = (channel['alternatives'] as List).first as Map<String, dynamic>;

  final transcript = alt['transcript'] as String? ?? '';
  final detectedLanguage = channel['detected_language'] as String? ?? '';

  // Попытка 1: paragraphs → sentences
  final paragraphsObj = alt['paragraphs'] as Map<String, dynamic>?;
  final paragraphsList = paragraphsObj?['paragraphs'] as List?;

  if (paragraphsList != null && paragraphsList.isNotEmpty) {
    final segments = <TranscriptionSegment>[];
    for (final para in paragraphsList) {
      final sentences = (para as Map<String, dynamic>)['sentences'] as List? ?? [];
      for (final s in sentences) {
        final sm = s as Map<String, dynamic>;
        segments.add(TranscriptionSegment(
          start: (sm['start'] as num).toDouble(),
          end: (sm['end'] as num).toDouble(),
          text: sm['text'] as String? ?? '',
        ));
      }
    }
    // duration = последний end последнего параграфа
    final lastPara = paragraphsList.last as Map<String, dynamic>;
    final duration = (lastPara['end'] as num?)?.toDouble() ?? 0.0;
    return TranscriptionResult(
      text: transcript,
      plainText: transcript,
      language: detectedLanguage,
      duration: duration,
      words: const [],
      segments: segments,
    );
  }

  // Попытка 2: words → segments fallback
  final wordsList = alt['words'] as List?;
  if (wordsList != null && wordsList.isNotEmpty) {
    final segments = wordsList.map((w) {
      final wm = w as Map<String, dynamic>;
      return TranscriptionSegment(
        start: (wm['start'] as num).toDouble(),
        end: (wm['end'] as num).toDouble(),
        text: wm['word'] as String? ?? '',
      );
    }).toList();
    final lastWord = wordsList.last as Map<String, dynamic>;
    final duration = (lastWord['end'] as num?)?.toDouble() ?? 0.0;
    return TranscriptionResult(
      text: transcript,
      plainText: transcript,
      language: detectedLanguage,
      duration: duration,
      words: const [],
      segments: segments,
    );
  }

  // Попытка 3: только плоский transcript
  return TranscriptionResult(
    text: transcript,
    plainText: transcript,
    language: detectedLanguage,
    duration: 0.0,
    words: const [],
    segments: const [],
  );
}
```

**Замечание:** `TranscriptionResult.fromJson` рассчитан на формат Groq (verbose_json). Для Deepgram нужен отдельный парсер прямо внутри `DeepgramProvider._parseResponse()` — не через `TranscriptionResult.fromJson`. `TranscriptionResult` создаётся вручную с уже спарсенными полями.

---

## Тесты — план

### Паттерн: MockClient для raw-body запроса [VERIFIED: test/unit/groq_transcribe_chunk_test.dart]

Для raw bytes запрос НЕ является `MultipartRequest`, поэтому стандартный `MockClient` из `package:http/testing.dart` работает напрямую (нет специфики перехвата multipart):

```dart
import 'package:http/testing.dart';

DeepgramProvider _providerWith(http.Client client) =>
    DeepgramProvider(clientFactory: () => client);

test('запрос содержит Authorization: Token', () async {
  Uri? capturedUri;
  Map<String, String>? capturedHeaders;

  final client = MockClient((request) async {
    capturedUri = request.url;
    capturedHeaders = request.headers;
    return http.Response(jsonEncode(_novaSuccessJson), 200,
        headers: {'content-type': 'application/json'});
  });
  ...
});
```

### Файл фикстур

Создать `test/fixtures/deepgram_nova3_response.json` с реальной структурой paragraphs/sentences/words для использования в тестах.

### Тест-кейсы `DeepgramProvider`

1. **Парсинг paragraphs:** JSON с `paragraphs.paragraphs[].sentences[]` → список `TranscriptionSegment`
2. **Fallback на words:** JSON без `paragraphs` → `TranscriptionSegment` из `words[]`
3. **Fallback plain text:** JSON без paragraphs и без words → один `TranscriptionResult` без segments
4. **URL и параметры:** `detect_language=true` при `auto`; `language=ru` при явном; `model=nova-3`, `smart_format=true`, `paragraphs=true`
5. **Заголовки:** `Authorization: Token <key>`, `Content-Type: audio/ogg`
6. **401 → AuthException**
7. **402 → KeyExhaustedException**
8. **429 → RateLimitException**
9. **504 → NetworkException**
10. **concurrencyFor:** `aliveKeyCount=0 → 0`; `aliveKeyCount=1 → 5`; `aliveKeyCount=3 → 5`

### Тест-кейс: выбор Deepgram без ключей → ChunkedMissingKey

```dart
// Контроллер с пустым пулом Deepgram + DeepgramProvider + nova3 options
// → start() → ChunkedMissingKey
```

---

## Общие ловушки (pitfalls)

### Pitfall 1: Authorization: Token vs Bearer
**Что ломается:** Groq использует `Bearer $apiKey`, Deepgram — `Token $apiKey` (без `Bearer`).
**Как избежать:** Явно указать `'Authorization': 'Token $apiKey'` в `DeepgramProvider`.
**Источник:** [VERIFIED: developers.deepgram.com/docs/paragraphs (curl пример)]

### Pitfall 2: paragraphs — двухуровневая вложенность
**Что ломается:** `alt['paragraphs']` — это объект `{transcript, paragraphs: [...]}`, а не сразу список. Прямой каст `as List` на `alt['paragraphs']` → `ClassCastException`.
**Как избежать:** `alt['paragraphs'] as Map` → `['paragraphs'] as List`.
**Источник:** [VERIFIED: developers.deepgram.com/docs/paragraphs]

### Pitfall 3: detected_language на уровне channel, не alternative
**Что ломается:** Поиск `detected_language` внутри `alternatives[0]` → null.
**Как избежать:** `channel['detected_language']` (уровень `channels[0]`).
**Источник:** [VERIFIED: developers.deepgram.com/docs/language-detection]

### Pitfall 4: duration отсутствует в ответе Deepgram
**Что ломается:** `TranscriptionResult.duration` используется `_assembleResult` для `fallbackChunkDuration`. Deepgram не возвращает явный `duration` field (в отличие от Groq verbose_json).
**Как избежать:** Вычислять `duration` как `end` последнего параграфа/слова/предложения. Если segments пусты и words пусты — `duration = 0.0` (контроллер использует `fallbackChunkDuration`).

### Pitfall 5: start/end нужны 0-based от начала чанка
**Что должно быть:** `sentences[].start` — секунды от начала чанка (Deepgram возвращает именно так). `_assembleResult` добавит `cumulativeStart`. Двойного прибавления нет.
**Риск:** если Deepgram когда-либо вернёт start от начала файла (не чанка) — таймкоды сдвинутся. При тестировании с многочанковым файлом проверить, что `segments[0].start` ≈ 0.

### Pitfall 6: SecureStorageServiceImpl.`_storageKey` — static
**Что ломается:** `static const _storageKey = AppConstants.storageKeyApiKeys` не позволяет передавать другой ключ через конструктор.
**Как избежать:** Изменить на `final String _storageKey` с инициализацией в конструкторе (см. раздел «Точки изменения»).

### Pitfall 7: transcriptionProviderProvider — сейчас возвращает только GroqProvider
**Что ломается:** `ProcessingScreen` читает `transcriptionProviderProvider` — всегда Groq.
**Как избежать:** Либо удалить этот provider из глобального DI и создавать провайдер в `ProcessingScreen` напрямую, либо сделать family. Рекомендуется удалить/не использовать — создавать `DeepgramProvider()` / `GroqProvider()` локально в ProcessingScreen по `options.model.provider`.

---

## Standard Stack

Никаких новых внешних зависимостей не требуется. [VERIFIED: pubspec.yaml]

| Библиотека | Версия | Роль в фазе 10 |
|-----------|--------|----------------|
| `http` | ^1.4.0 | raw-body POST запросы к Deepgram |
| `http/testing.dart` (встроен) | — | MockClient для тестов |
| `flutter_riverpod` | ^2.6.1 | DI — новые провайдеры пула/репозитория |
| `flutter_secure_storage` | ^10.2.0 | namespace `deepgram_api_keys_v1` |
| `clock` | ^1.1.1 | уже используется KeyPool |
| `fake_async` | transitive | тесты KeyPool |

**Нет новых `pub add`.**

---

## Package Legitimacy Audit

Новые пакеты не добавляются. Audit не требуется.

---

## Environment Availability

Step 2.6: SKIPPED (фаза 10 — code-only изменения, нет новых внешних сервисов; Deepgram API вызывается во runtime, не при сборке).

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (встроен) |
| Config file | нет отдельного (flutter test стандартный) |
| Quick run command | `flutter test test/unit/deepgram_provider_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req | Поведение | Тип | Файл теста |
|-----|-----------|-----|-----------|
| R-DG-01 | Правильный URL/заголовки/body при запросе | unit | `test/unit/deepgram_provider_test.dart` ❌ Wave 0 |
| R-DG-02 | Парсинг paragraphs → TranscriptionSegment | unit | `test/unit/deepgram_provider_test.dart` ❌ Wave 0 |
| R-DG-03 | Fallback на words при отсутствии paragraphs | unit | `test/unit/deepgram_provider_test.dart` ❌ Wave 0 |
| R-DG-04 | 401→Auth, 402→Exhausted, 429→RateLimit, 504→Network | unit | `test/unit/deepgram_provider_test.dart` ❌ Wave 0 |
| R-DG-05 | concurrencyFor: Deepgram `n>0→5`, `0→0` | unit | `test/unit/deepgram_provider_test.dart` ❌ Wave 0 |
| R-DG-06 | Nova-3 без DG-ключей → ChunkedMissingKey | unit | `test/features/transcription/chunked_transcription_controller_test.dart` ✅ |
| R-DG-07 | Регрессия: существующие Groq-тесты зелёные | regression | все `test/unit/groq*` ✅ |
| R-DG-08 | DI: deepgramKeyPoolProvider переопределяется в main | smoke | `test/widget/home_screen_smoke_test.dart` (расширить) |

### Wave 0 Gaps

- [ ] `test/unit/deepgram_provider_test.dart` — новый файл, covers R-DG-01..05
- [ ] `test/fixtures/deepgram_nova3_response.json` — JSON фикстура с paragraphs/sentences/words
- [ ] `test/fixtures/deepgram_nova3_response_empty.json` — фикстура для тишины/пустого ответа

---

## Обновление CLAUDE.md

SPEC требует обновить ограничение `API: только Groq Whisper` → два провайдера через `dscs-updater`. Это задача плановика: в плане должен быть таск на вызов `dscs-updater` после успешной реализации.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Deepgram возвращает `detected_language` даже при `language=<iso>` (не только при `detect_language=true`) | Pitfall 3 | `language` в `TranscriptionResult` будет пустой строкой — не критично для функциональности |
| A2 | `sentences[].start` у Deepgram всегда 0-based от начала chunk, а не от начала файла | Pitfall 5 | Сдвиг таймкодов в assembled результате |
| A3 | Deepgram возвращает `retry-after` заголовок при 429 | Pitfall / RateLimitException | Если нет — используется fallback 60 с (некритично) |
| A4 | `smart_format=true` + `paragraphs=true` доступны на free tier | Standard Stack | Если требуют платного плана — paragraphs не вернутся, сработает fallback на words/plain |

---

## Open Questions (RESOLVED)

1. **`detected_language` при явном языке**
   - Что знаем: при `detect_language=true` — в ответе есть `detected_language` на уровне channel.
   - Неясно: возвращается ли `detected_language` при явном `language=ru` (не `detect_language`)?
   - Рекомендация: сохранять `options.language.isoCode` как fallback для `TranscriptionResult.language` если `detected_language` пуст.
   - RESOLVED: fallback на options.language.isoCode, если detected_language пуст (реализовано в deepgram_provider.dart, план 10-01).

2. **Обработка `paragraphs` при тишине/шуме**
   - Что знаем: при пустом транскрипте `alternatives` может быть пустым или содержать пустой `transcript`.
   - Неясно: возвращает ли Deepgram `channels: []` или `channels: [{alternatives: []}]`?
   - Рекомендация: защитный null-check: `channels?.isNotEmpty == true ? channels.first : null`; вернуть `TranscriptionResult.empty()`.
   - RESOLVED: защитный null-check на пустые channels/alternatives → TranscriptionResult.empty() (реализовано в deepgram_provider.dart, план 10-01).

---

## Sources

### Primary (HIGH confidence)
- `lib/features/transcription/transcription_provider.dart` — точные сигнатуры интерфейса
- `lib/features/transcription/key_pool.dart` — KeyPool API, ExhaustedKeyStatus, reportExhausted
- `lib/core/error/app_exception.dart` — все нормализованные исключения
- `lib/features/transcription/groq_api_service.dart` — паттерн реализации TranscriptionProvider
- `lib/features/transcription/transcription_options.dart` — уже существующие TranscriptionModel.nova3, TranscriptionProviderId.deepgram
- `lib/core/storage/secure_storage_service.dart` — текущая реализация (static _storageKey)
- `lib/core/providers/service_providers.dart` — текущие DI провайдеры
- `lib/main.dart` — текущий bootstrap паттерн
- `lib/ui/screens/processing_screen.dart` — хардкод groqKeyPoolProvider/transcriptionProviderProvider
- [developers.deepgram.com/docs/paragraphs](https://developers.deepgram.com/docs/paragraphs) — точная JSON структура paragraphs/sentences
- [developers.deepgram.com/docs/language-detection](https://developers.deepgram.com/docs/language-detection) — `detected_language` поле на уровне channel
- [developers.deepgram.com/docs/errors](https://developers.deepgram.com/docs/errors) — коды 401/402/429

### Secondary (MEDIUM confidence)
- `test/unit/groq_transcribe_chunk_test.dart` — паттерн MockClient + `_MultipartCapturingClient`
- `test/helpers/transcription_mocks.dart` — MockTranscriptionProvider, FakeChunkFile паттерны

---

## Metadata

**Confidence breakdown:**
- Существующий код (provider interface, KeyPool, exceptions): HIGH — прочитан напрямую
- Deepgram API структура ответа: HIGH — верифицирован по официальной документации
- Deepgram HTTP error codes: HIGH — верифицирован по официальной документации
- Точки изменения DI/storage: HIGH — прочитан весь слой провайдеров и хранилища

**Research date:** 2026-06-10
**Valid until:** 2026-07-10 (API стабильный, Deepgram версионирует breakings)
