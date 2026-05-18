---
phase: 04-multi-key-pool
verified: 2026-05-18T12:00:00Z
status: gaps_found
score: 12/13 must-haves verified
overrides_applied: 0
gaps:
  - truth: "При получении 503 от Groq ключ автоматически блокируется — аналогично 429"
    status: failed
    reason: "groq_api_service.dart обрабатывает только statusCode == 429 как RateLimitException. HTTP 503 падает в общий NetworkException без reportRateLimited. ROADMAP success criterion 3 явно указывает '429/503'."
    artifacts:
      - path: "lib/features/transcription/groq_api_service.dart"
        issue: "Блок if (response.statusCode == 429) не включает 503; 503 уходит в NetworkException без парсинга retry-after заголовков"
    missing:
      - "Добавить ветку для 503 в transcribeChunk (аналогично 429): if (response.statusCode == 503) { ... throw RateLimitException(..., retryAfterSeconds: parseRetryAfterFromHeaders(response.headers)); }"
      - "Добавить тест '503 блокирует ключ аналогично 429' в test/unit/groq_api_service_rate_limit_test.dart (тест упоминался в плане 04-01 task 1 behavior, но отсутствует в финальном файле)"
human_verification:
  - test: "Запустить приложение на Android-устройстве, добавить два ключа, проверить что оба отображаются с зелёным индикатором «Активен»"
    expected: "Экран API-ключей показывает KeyStatusTile с зелёным кружком и текстом «Активен» для каждого ключа; UI обновляется без перезагрузки экрана при добавлении нового ключа"
    why_human: "Поведение Timer.periodic и ListenableBuilder в реальном времени на устройстве нельзя подтвердить статическим анализом"
  - test: "Спровоцировать реальный 429 от Groq (транскрибация с превышенным лимитом) и проверить что заблокированный ключ показывает красный обратный отсчёт «До HH:MM:SS»"
    expected: "KeyStatusTile переходит в красное состояние, обратный отсчёт убывает каждую секунду в реальном времени, второй ключ продолжает отправлять чанки"
    why_human: "Требует реального HTTP 429-ответа от Groq и наблюдения реального поведения UI"
  - test: "Проверить ссылку «Получить ключ на console.groq.com» на экране API-ключей"
    expected: "Тап открывает браузер с https://console.groq.com/keys"
    why_human: "launchUrl — внешний вызов; не тестируется в unit/widget тестах"
---

# Phase 04: Multi-Key Pool & Rate-Limit UI — Verification Report

**Phase Goal:** Пользователь добавляет несколько Groq-ключей и видит, какие из них активны / заблокированы / сколько квоты осталось; пул сам ротирует ключи и переживает 429.
**Verified:** 2026-05-18T12:00:00Z
**Status:** gaps_found (1 BLOCKER — 503 не обрабатывается как RateLimitException)
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | GroqKeyPool.acquireKey() возвращает живой ключ по round-robin | ✓ VERIFIED | `groq_key_pool.dart`: `_nextAlive()` с циклическим индексом; тест `round_robin выдаёт ключи по очереди` — 7 тестов green |
| 2 | Заблокированный ключ пропускается, acquireKey() ждёт разблокировки | ✓ VERIFIED | `groq_key_pool.dart` строки 80–93 (`_nextAlive` пропускает `_isBlocked`), строки 130–146 (`acquireKey` + Completer-очередь) |
| 3 | При таймауте 10 мин бросается AllKeysBlockedException | ✓ VERIFIED | `groq_key_pool.dart` строка 140: `.timeout(Duration(minutes: 10), onTimeout: () { ... throw const AllKeysBlockedException() })`; тест `таймаут 10 мин → AllKeysBlockedException` |
| 4 | RateLimitException содержит retryAfterSeconds | ✓ VERIFIED | `app_exception.dart` строки 34–37: `final int retryAfterSeconds; const RateLimitException(super.message, {this.retryAfterSeconds = 60})` |
| 5 | GroqApiService парсит retry-after / x-ratelimit-reset-* из 429-ответа | ✓ VERIFIED | `groq_api_service.dart` строки 27–53: top-level `parseRetryAfterFromHeaders`, вызывается в блоке 429; 5 тестов green |
| 6 | При получении 503 от Groq ключ блокируется аналогично 429 | ✗ FAILED | `groq_api_service.dart` строка 142–154: обрабатывается только `statusCode == 429`; 503 падает в `NetworkException`. ROADMAP SC-3 явно требует "429/503". |
| 7 | Fallback 60 с если заголовки отсутствуют | ✓ VERIFIED | `groq_api_service.dart` строка 52: `return 60`; тест `fallback 60 если заголовки отсутствуют` |
| 8 | ChunkedTranscriptionController использует pool.acquireKey() (не ApiKeyRepository) | ✓ VERIFIED | `chunked_transcription_controller.dart` строка 257: `final key = await _pool.acquireKey()`; импорт `api_key_repository.dart` отсутствует |
| 9 | TranscriptionController использует pool.acquireKey() (не ApiKeyRepository) | ✓ VERIFIED | `transcription_controller.dart` строка 84: `key = await _pool.acquireKey()`; импорт `api_key_repository.dart` отсутствует |
| 10 | GroqKeyPool создан в main.dart с initialKeys из ApiKeyRepository | ✓ VERIFIED | `main.dart` строки 16–21: `final rawKeys = await repository.listKeys(); final groqKeyPool = GroqKeyPool(initialKeys: rawKeys.map((k) => k.raw).toList())` |
| 11 | ApiKeysScreen подписана на GroqKeyPool через ListenableBuilder | ✓ VERIFIED | `api_keys_screen.dart` строки 122–159: `ListenableBuilder(listenable: widget.pool, builder: ...)` оборачивает список ключей |
| 12 | Для каждого ключа виден статус (KeyStatusTile) с pool.getStatusForKey() | ✓ VERIFIED | `api_keys_screen.dart` строка 141–143: `KeyStatusTile(status: widget.pool.getStatusForKey(key.raw))`; widget-тесты green (3/3) |
| 13 | maxConcurrent = min(pool.aliveKeyCount, kMaxConcurrentChunks) в chunked контроллере | ✓ VERIFIED | `chunked_transcription_controller.dart` строки 197–200: `final concurrency = min(_pool.aliveKeyCount.clamp(1, AppConstants.kMaxConcurrentChunks), AppConstants.kMaxConcurrentChunks)` |

**Score:** 12/13 truths verified

---

## Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/features/transcription/groq_key_pool.dart` | GroqKeyPool extends ChangeNotifier; acquireKey/reportRateLimited/releaseKey/getStatuses/addKey/removeKey/allKeys/aliveKeyCount | ✓ VERIFIED | Все методы реализованы; 209 строк, substantive |
| `lib/core/error/all_keys_blocked_exception.dart` | AllKeysBlockedException | ✓ VERIFIED | Re-export файл; `AllKeysBlockedException` определён в `app_exception.dart` (sealed class ограничение Dart) |
| `lib/core/error/app_exception.dart` | RateLimitException с полем retryAfterSeconds: int | ✓ VERIFIED | Строки 34–37; поле с дефолтом 60 |
| `lib/core/constants/app_constants.dart` | kMaxConcurrentChunks = 5 | ✓ VERIFIED | Строка 40: `static const int kMaxConcurrentChunks = 5` |
| `lib/features/transcription/groq_api_service.dart` | top-level parseRetryAfterFromHeaders | ✓ VERIFIED | Строки 27–53; top-level функция для тестируемости |
| `lib/features/transcription/chunked_transcription_controller.dart` | pool.acquireKey() вместо ApiKeyRepository | ✓ VERIFIED | Принимает `GroqKeyPool pool`, `acquireKey()` на строке 257 |
| `lib/features/transcription/transcription_controller.dart` | pool.acquireKey() вместо ApiKeyRepository | ✓ VERIFIED | Принимает `GroqKeyPool pool`, `acquireKey()` на строке 84 |
| `lib/main.dart` | GroqKeyPool singleton с initialKeys из SecureStorage | ✓ VERIFIED | Строки 16–23 |
| `lib/ui/widgets/key_status_tile.dart` | KeyStatusTile StatefulWidget с Timer.periodic + dispose cancel | ✓ VERIFIED | `initState`, `didUpdateWidget`, `dispose` с `_timer?.cancel()`, 100 строк |
| `lib/ui/screens/api_keys_screen.dart` | ApiKeysScreen принимает GroqKeyPool, ListenableBuilder, pool.addKey/removeKey sync | ✓ VERIFIED | Строки 19–27 (конструктор с `required this.pool`), строки 71/105 (sync) |
| `test/features/settings/groq_key_pool_test.dart` | Юнит-тесты TRANS-01: round-robin, skip_blocked, wait_for_unblock, timeout | ✓ VERIFIED | 7 тестов; все 4 поведения из PLAN.md покрыты + 3 дополнительных |
| `test/unit/groq_api_service_rate_limit_test.dart` | Юнит-тесты TRANS-02: parse_retry_after, duration_string, fallback | ✓ VERIFIED | 5 тестов; 503-тест отсутствует (связан с gap выше) |
| `test/widget/api_keys_screen_status_test.dart` | Widget-тесты KEYS-05: активный ключ, заблокированный с countdown | ✓ VERIFIED | 3 widget-теста |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `lib/features/transcription/groq_key_pool.dart` | `lib/features/transcription/groq_api_service.dart` | `acquireKey()` → `apiKey` параметр `transcribeChunk` | ✓ WIRED | `chunked_transcription_controller.dart` строка 261: `_api.transcribeChunk(..., apiKey: key)` где `key = await _pool.acquireKey()` |
| `lib/features/transcription/groq_api_service.dart` | `lib/core/error/app_exception.dart` | `parseRetryAfterFromHeaders` → `RateLimitException.retryAfterSeconds` | ✓ WIRED | Строка 148: `throw RateLimitException('...', retryAfterSeconds: retryAfterSeconds)` |
| `lib/main.dart` | `lib/features/transcription/groq_key_pool.dart` | `GroqKeyPool(initialKeys: keys.map((k) => k.raw).toList())` | ✓ WIRED | `main.dart` строки 19–22 |
| `lib/features/transcription/chunked_transcription_controller.dart` | `lib/features/transcription/groq_key_pool.dart` | `_pool.acquireKey()` в while-loop | ✓ WIRED | Строки 257, 279 |
| `lib/features/transcription/transcription_controller.dart` | `lib/features/transcription/groq_key_pool.dart` | `_pool.acquireKey()` + `reportRateLimited` в retry-loop | ✓ WIRED | Строки 84, 101 |
| `lib/ui/screens/api_keys_screen.dart` | `lib/features/transcription/groq_key_pool.dart` | `ListenableBuilder(listenable: widget.pool)` + `getStatusForKey()` | ✓ WIRED | Строки 122–143 |
| `lib/ui/widgets/key_status_tile.dart` | `lib/features/transcription/groq_key_pool.dart` | `KeyStatus → BlockedKeyStatus.blockedUntil` | ✓ WIRED | Строка 92: `if (s is BlockedKeyStatus)` |

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| TRANS-01 | 04-01, 04-02 | Round-robin ротация ключей | ✓ SATISFIED | GroqKeyPool.acquireKey() + _nextAlive(); тесты green |
| TRANS-02 | 04-01 | Парсинг retry-after заголовков | ✓ SATISFIED | parseRetryAfterFromHeaders; 5 тестов |
| KEYS-03 | 04-02, 04-03 | Пул управляет несколькими ключами | ✓ SATISFIED | addKey/removeKey/getStatuses |
| KEYS-04 | 04-03 | Ссылка console.groq.com/keys кликабельна | ✓ SATISFIED | `api_keys_screen.dart` строки 265–269: `launchUrl(Uri.parse('https://console.groq.com/keys'), ...)` |
| KEYS-05 | 04-03 | UI статуса ключей в реальном времени | ✓ SATISFIED | KeyStatusTile + ListenableBuilder; 3 widget-теста green |

### ROADMAP Success Criteria Coverage

| SC# | Criterion | Status | Notes |
|-----|-----------|--------|-------|
| SC-1 | Пользователь может добавить N ключей, удалить, открыть ссылку на console.groq.com/keys | ✓ SATISFIED | addKey/removeKey/launchUrl |
| SC-2 | Чанки распределяются round-robin между живыми ключами | ✓ SATISFIED | pool.acquireKey() в _processChunk while-loop |
| SC-3 | При получении **429/503** ключ блокируется на время из заголовков; другие чанки продолжают | ✗ PARTIALLY | 429 — реализовано; **503 — NetworkException без блокировки** |
| SC-4 | Для каждого ключа в UI: статус (активен / заблокирован до HH:MM:SS); обновляется в реальном времени | ✓ SATISFIED | KeyStatusTile + Timer.periodic + ListenableBuilder |
| SC-5 | Часовая лекция на двух ключах расшифровывается без вмешательства | ? NEEDS HUMAN | Требует реального устройства и длинной транскрибации |

---

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `lib/features/transcription/groq_key_pool.dart` | 164–166 | `releaseKey` — заглушка с пустым телом | ℹ️ Info | Задокументирована в коде; соответствует плану (round-robin не требует явного release). Не блокирует. |
| `lib/features/transcription/groq_api_service.dart` | 142–149 | 503 не обрабатывается как RateLimitException | 🛑 Blocker | ROADMAP SC-3 требует "429/503"; 503 уходит в NetworkException |

Маркеры TBD/FIXME/XXX в изменённых файлах: не обнаружены.

---

## Behavioral Spot-Checks

| Поведение | Проверка | Результат | Статус |
|-----------|----------|-----------|--------|
| `parseRetryAfterFromHeaders({'retry-after': '45'}) == 45` | Код прочитан: строки 29–35 groq_api_service.dart | `int.tryParse('45') = 45`, `min(45, 3600) = 45` | ✓ PASS |
| `parseRetryAfterFromHeaders({'x-ratelimit-reset-requests': '2m59.56s'}) == 180` | Код прочитан: строки 38–48 | 2×60 + ceil(59.56)=60 → 120+60=180; `min(180,3600)=180` | ✓ PASS |
| `parseRetryAfterFromHeaders({}) == 60` | Строка 52 | `return 60` | ✓ PASS |
| `kMaxConcurrentChunks == 5` | `app_constants.dart` строка 40 | `static const int kMaxConcurrentChunks = 5` | ✓ PASS |
| Timer.cancel в dispose KeyStatusTile | `key_status_tile.dart` строка 44 | `_timer?.cancel()` перед `super.dispose()` | ✓ PASS |

---

## Probe Execution

Step 7c: SKIPPED — фаза не декларирует probe-скрипты; `scripts/*/tests/probe-*.sh` не найдены.

---

## Gaps Summary

**1 BLOCKER обнаружен:** HTTP 503 не обрабатывается как `RateLimitException` в `groq_api_service.dart` метод `transcribeChunk`.

ROADMAP success criterion 3 прямо требует: *"При получении **429/503** от Groq ключ автоматически блокируется на время из заголовков"*. Текущая реализация обрабатывает только 429. При 503 бросается `NetworkException` — контроллер фиксирует ошибку и останавливается, вместо того чтобы заблокировать ключ и продолжить на других ключах.

**Исправление простое:** добавить ветку `if (response.statusCode == 503)` параллельно с 429 в методе `transcribeChunk`, аналогично тому как это было описано в `04-01-PLAN.md` task 3 behavior ("503 блокирует ключ аналогично 429") и в test stubs task 1 behavior ("503 блокирует ключ аналогично 429").

Все остальные 12 из 13 требований фазы полностью выполнены: GroqKeyPool функционален, контроллеры мигрированы, UI реактивный, тесты green, коммиты существуют.

---

**Человеческое UAT требуется** (3 пункта) — для визуального и real-time поведения на устройстве.

---

_Verified: 2026-05-18T12:00:00Z_
_Verifier: Claude (gsd-verifier)_
