---
phase: 10-deepgram-provider
reviewed: 2026-06-10T00:00:00Z
depth: standard
files_reviewed: 12
files_reviewed_list:
  - lib/core/constants/app_constants.dart
  - lib/core/providers/repository_providers.dart
  - lib/core/providers/service_providers.dart
  - lib/core/providers/storage_providers.dart
  - lib/core/storage/secure_storage_service.dart
  - lib/features/settings/api_key_repository.dart
  - lib/features/transcription/deepgram_provider.dart
  - lib/main.dart
  - lib/ui/screens/processing_screen.dart
  - test/unit/deepgram_provider_test.dart
  - test/features/transcription/chunked_transcription_controller_test.dart
  - test/widget/home_screen_smoke_test.dart
findings:
  critical: 3
  warning: 4
  info: 3
  total: 10
status: issues_found
---

# Phase 10: Code Review Report

**Reviewed:** 2026-06-10  
**Depth:** standard  
**Files Reviewed:** 12  
**Status:** issues_found

## Summary

Рецензируется реализация `DeepgramProvider` (фаза 10): новый провайдер транскрибации через Deepgram nova-3 REST API, параметризованный `SecureStorageService`, второй `KeyPool` для Deepgram, DI-обвязка и маршрутизация по `options.model.provider`.

Общее качество реализации хорошее: API-ключ не логируется, используется заголовок `Token`, тело ответа обрезается до 200 символов. Вместе с тем обнаружены три блокирующих проблемы: утечка API-ключа в тексте исключения при сетевых ошибках, TOCTOU-гонка в хранилище ключей, и молчаливое поглощение ошибок парсинга JSON, а также четыре предупреждения.

---

## Critical Issues

### CR-01: API-ключ попадает в текст исключения `NetworkException` при ошибках с телом ответа

**File:** `lib/features/transcription/deepgram_provider.dart:106`  
**Issue:** В строке 106 тело ответа вставляется в сообщение `NetworkException`:
```dart
throw NetworkException('Deepgram ${response.statusCode}: $safeBody');
```
Deepgram в ряде случаев эхом возвращает параметры запроса (в том числе при нестандартных 4xx — например, 403) в теле ответа в виде JSON вида `{"error": "...", "request_id": "...", "key": "..."}`. Обрезание до 200 символов не является гарантией: 200 символов достаточно для полного включения ключа в сообщение. Кроме того, сообщение `NetworkException.message` поднимается в UI (`processing_screen.dart:399`) и может быть отображено пользователю или записано в отладочные логи фреймворком.

Отдельно: коды 403 (запрещённый доступ), 400 (неверный запрос) вообще не обрабатываются отдельно — они падают в ветку `NetworkException` с телом ответа, которое может содержать чувствительные данные.

**Fix:**
```dart
// Не включать тело ответа в сообщение исключения вообще.
// Для диагностики достаточно HTTP-кода.
throw NetworkException('Deepgram error ${response.statusCode}');
```
Если диагностика тела действительно нужна — пишите в отдельный защищённый лог-канал (не в текст публичного исключения), либо санируйте тело, парсируя только известные безопасные JSON-поля (`detail`, `message`, `error`), явно исключая поля с токенами.

---

### CR-02: TOCTOU-гонка в `SecureStorageServiceImpl.addApiKey` — дублирование ключа возможно

**File:** `lib/core/storage/secure_storage_service.dart:80–85`  
**Issue:** `addApiKey` выполняет read–check–write в три отдельных асинхронных операции без какой-либо блокировки:
```dart
final keys = await listApiKeys();   // read
if (!keys.contains(key)) {          // check (не атомарно с read выше)
  keys.add(key);
  await _storage.write(...);        // write
}
```
Если два параллельных вызова `addApiKey` с одним и тем же ключом (или двумя разными) начнутся практически одновременно, оба пройдут проверку `contains` на устаревшем снимке списка и оба запишут результат — последний перезапишет первый. Это означает: можно потерять недавно добавленный ключ, или ключ появится дважды (если они разные). В production-сценарии это случается при быстром тапе "Добавить" дважды.

**Fix:**
```dart
// Вариант А (предпочтительный): мьютекс через пакет synchronized.
import 'package:synchronized/synchronized.dart';
final _lock = Lock();

@override
Future<void> addApiKey(String key) async {
  await _lock.synchronized(() async {
    final keys = await listApiKeys();
    if (!keys.contains(key)) {
      keys.add(key);
      await _storage.write(key: _storageKey, value: jsonEncode(keys));
    }
  });
}
```
Аналогично `removeApiKey` также нужно защитить тем же `_lock`.

---

### CR-03: Исключения парсинга JSON поглощаются в `_parseResponse` — некорректный ответ становится пустым результатом без уведомления

**File:** `lib/features/transcription/deepgram_provider.dart:72–77`  
**Issue:** В `transcribeChunk` блок `catch (_)` при `statusCode == 200` перехватывает любое исключение при `jsonDecode` и бросает `InternalException`. Это само по себе правильно. Однако в `_parseResponse` (строки 132, 138, 155, 157, 163, 183, 190) многочисленные приведения типов (`as Map<String, dynamic>`, `as List?`, `as num`) выполнены без обработки: если Deepgram изменит схему ответа (например, `start`/`end` станут `String` вместо `num`), бросится `TypeError`, который будет поглощён внешним `catch (_)` (строка 113–114), и метод вернёт `NetworkException(_networkErrorMessage)` — то есть безобидная ошибка схемы будет замаскирована под сетевую ошибку. Это делает диагностику нарушений контракта API фактически невозможной.

Хуже того: при работе через `paragraphsList` (строка 153–164) приведение `(sm['start'] as num).toDouble()` кинет `TypeError` при `null` (когда поле `start` отсутствует). `_parseResponse` не является async-методом и вызывается внутри `try { ... } on AppException { rethrow } catch (_) { throw NetworkException(...) }` — таким образом `TypeError` превратится в `NetworkException`, скрыв реальную причину.

**Fix:**
```dart
// В _parseResponse использовать безопасное приведение через num? и nullable-цепочки:
start: ((sm['start'] as num?)?.toDouble()) ?? 0.0,
end:   ((sm['end']   as num?)?.toDouble()) ?? 0.0,
text:  sm['text'] as String? ?? '',

// Аналогично для words-fallback:
start: ((wm['start'] as num?)?.toDouble()) ?? 0.0,
end:   ((wm['end']   as num?)?.toDouble()) ?? 0.0,
```
А во внешнем `catch (_)` (строка 113) рекомендуется перебрасывать как `InternalException`, а не `NetworkException`, чтобы не смешивать классы ошибок:
```dart
} catch (e) {
  if (e is TypeError) throw InternalException('Неожиданная схема ответа Deepgram: $e');
  throw const NetworkException(_networkErrorMessage);
}
```

---

## Warnings

### WR-01: `secureStorageProvider` игнорирует константу `storageKeyApiKeys` — хардкодированный дефолт в другом месте

**File:** `lib/core/providers/storage_providers.dart:8`  
**Issue:** `secureStorageProvider` создаёт `SecureStorageServiceImpl()` без аргументов. Фактический ключ хранилища задаётся дефолтным параметром в конструкторе `SecureStorageServiceImpl` (строка 36 `secure_storage_service.dart`): `AppConstants.storageKeyApiKeys`. Это работает, но создаёт неявную зависимость: если когда-либо изменить дефолтное значение параметра, `secureStorageProvider` молча сменит namespace и потеряет все существующие ключи пользователей.

`deepgramSecureStorageProvider` (строка 13) явно передаёт `storageKey:`, что правильно. Стиль должен быть единообразным.

**Fix:**
```dart
final secureStorageProvider = Provider<SecureStorageService>(
  (ref) => SecureStorageServiceImpl(
    storageKey: AppConstants.storageKeyApiKeys,
  ),
);
```

---

### WR-02: `main.dart` — ошибка при загрузке ключей из `SecureStorage` приведёт к краху приложения без обработки

**File:** `lib/main.dart:20–23`  
**Issue:** Вызовы `await bootstrap.read(apiKeyRepoProvider).listKeys()` и `await bootstrap.read(deepgramApiKeyRepoProvider).listKeys()` не обёрнуты в `try/catch`. Если `flutter_secure_storage` выбросит исключение (например, при первом запуске на устройстве с повреждённым keystore, после factory reset, или при ошибке платформы), приложение упадёт с необработанным исключением до запуска `runApp`. Пользователь увидит чёрный экран без возможности восстановления.

**Fix:**
```dart
List<ApiKeyView> groqRawKeys = [];
List<ApiKeyView> deepgramRawKeys = [];
try {
  groqRawKeys = await bootstrap.read(apiKeyRepoProvider).listKeys();
  deepgramRawKeys = await bootstrap.read(deepgramApiKeyRepoProvider).listKeys();
} catch (_) {
  // Не можем читать ключи — запускаем с пустыми пулами, пользователь добавит ключи вручную.
}
bootstrap.dispose();
```

---

### WR-03: `processing_screen.dart` — `DeepgramProvider()` и `GroqProvider()` создаются напрямую, минуя DI

**File:** `lib/ui/screens/processing_screen.dart:139`  
**Issue:**
```dart
apiService: _isDeepgram ? DeepgramProvider() : GroqProvider(),
```
Оба провайдера инстанциируются непосредственно в виджете, без Riverpod-провайдера. Это нарушает инверсию зависимостей: невозможно подменить провайдер в тестах через `ProviderScope.overrides`, нельзя переиспользовать один экземпляр для нескольких экранов, невозможно инжектировать mock для виджет-тестов `ProcessingScreen`. Кроме того, любой новый параметр конфигурации провайдера (например, `clientFactory` для Deepgram) придётся передавать через весь виджет-слой.

**Fix:**
```dart
// В service_providers.dart добавить:
final groqProviderProvider = Provider<TranscriptionProvider>((_) => GroqProvider());
final deepgramProviderProvider = Provider<TranscriptionProvider>((_) => DeepgramProvider());

// В processing_screen.dart:
apiService: _isDeepgram
    ? ref.read(deepgramProviderProvider)
    : ref.read(groqProviderProvider),
```

---

### WR-04: `ApiKeyRepository.mask()` раскрывает фиксированную длину маскировки независимо от длины ключа

**File:** `lib/features/settings/api_key_repository.dart:44–49`  
**Issue:**
```dart
static String mask(String key) {
  if (key.length < 8) {
    return '•' * 8;
  }
  final tail = key.substring(key.length - 4);
  return '${'•' * 16}$tail';  // всегда 16+4=20 символов
}
```
Маска всегда имеет длину 20 символов вне зависимости от реальной длины ключа. Это незначительно раскрывает информацию (наблюдатель знает, что длина ключа ≥ 8, но не более), однако важнее другое: для ключей длиной 8–19 символов хвост `.substring(key.length - 4)` будет совпадать с большей частью ключа (например, ключ из 8 символов: 4 последних символа — это половина ключа). Для реальных Groq-ключей (50+ символов) и Deepgram-ключей (40+ символов) это не критично, но формальная проверка `_minKeyLength = 20` в `addKey` всё же допускает ключи от 20 до 23 символов, где маска будет раскрывать от 17 до 20% ключа.

**Fix:**
```dart
static String mask(String key) {
  if (key.length < 8) return '•' * 8;
  final tail = key.substring(key.length - 4);
  // Маскируем всё кроме последних 4 символов, независимо от длины ключа.
  final dots = '•' * (key.length - 4).clamp(4, 32);
  return '$dots$tail';
}
```

---

## Info

### IN-01: `DeepgramProvider.concurrencyFor` — константа 5 хардкодирована, не ссылается на `AppConstants.kMaxConcurrentChunks`

**File:** `lib/features/transcription/deepgram_provider.dart:215`  
**Issue:**
```dart
int concurrencyFor(int aliveKeyCount) => aliveKeyCount > 0 ? 5 : 0;
```
Значение `5` совпадает с `AppConstants.kMaxConcurrentChunks = 5`, но не использует константу. При изменении `kMaxConcurrentChunks` Deepgram-провайдер не изменится автоматически. Семантически это разные вещи: `kMaxConcurrentChunks` — верхний предел, а здесь — фиксированное число независимо от количества ключей. Если семантика действительно отличается — добавьте отдельную именованную константу.

**Fix:**
```dart
// Если поведение «всегда 5 при наличии ключей» намеренное — выделить константу:
static const int _deepgramConcurrency = 5;

int concurrencyFor(int aliveKeyCount) => aliveKeyCount > 0 ? _deepgramConcurrency : 0;
```

---

### IN-02: `TranscriptionLanguage.auto` имеет `isoCode = ''` — в `deepgram_provider.dart` пустая строка попадёт в `detectedLanguage` при отсутствии `detected_language`

**File:** `lib/features/transcription/deepgram_provider.dart:143–144`  
**Issue:**
```dart
final detectedLanguage =
    channel['detected_language'] as String? ?? options.language.isoCode;
```
При `TranscriptionLanguage.auto` значение `isoCode` равно `''` (пустая строка). Если Deepgram не вернул `detected_language` (например, при тихом аудио), `detectedLanguage` станет `''`. Это пустое значение языка попадёт в `TranscriptionResult.language` и может вызвать неожиданное поведение в потребителях этого поля (поиск субтитров, отображение метаданных и т.д.).

**Fix:**
```dart
final rawDetectedLanguage = channel['detected_language'] as String?;
final detectedLanguage = (rawDetectedLanguage != null && rawDetectedLanguage.isNotEmpty)
    ? rawDetectedLanguage
    : (options.language.isoCode.isNotEmpty ? options.language.isoCode : 'unknown');
```

---

### IN-03: Тест `deepgram_provider_test.dart` использует `const fakeKey = 'dg_testkey_abc123'` длиной 17 символов — не проходит валидацию `_minKeyLength = 20`

**File:** `test/unit/deepgram_provider_test.dart:31`  
**Issue:**
```dart
const fakeKey = 'dg_testkey_abc123';  // длина = 17
```
`ApiKeyRepository._minKeyLength = 20`. Тест для `DeepgramProvider` использует ключ, который не прошёл бы валидацию в репозитории. Это не вызывает сбоя теста, поскольку `DeepgramProvider.transcribeChunk` принимает ключ без валидации (что правильно — провайдер не несёт ответственности за валидацию). Однако несоответствие создаёт путаницу и может привести к ложной уверенности, что 17-символьные ключи допустимы.

**Fix:**
```dart
// Использовать тестовый ключ достаточной длины (≥ 20 символов):
const fakeKey = 'dg_test_key_abcdef1234';
```

---

_Reviewed: 2026-06-10_  
_Reviewer: Claude (gsd-code-reviewer)_  
_Depth: standard_
