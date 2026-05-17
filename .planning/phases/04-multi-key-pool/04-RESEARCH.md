# Phase 4: Multi-Key Pool & Rate-Limit UI — Research

**Researched:** 2026-05-17
**Domain:** Flutter ChangeNotifier, Groq rate-limit headers, async Completer patterns
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** `GroqKeyPool extends ChangeNotifier` — синглтон, создаётся в `main.dart`, передаётся как зависимость. UI слушает через `ListenableBuilder`.
- **D-02:** Состояние пула только в памяти (`blockedUntil: DateTime`). Персист через рестарт не нужен.
- **D-03:** Интерфейс пула: `acquireKey()` (async, ждёт живой ключ), `reportRateLimited(key, seconds)`, `getStatuses()` → `List<KeyStatus>`.
- **D-04:** Контроллер сообщает пулу о 429: `pool.reportRateLimited(key, e.retryAfterSeconds)`, затем снова `pool.acquireKey()`. Логика round-robin инкапсулирована в пуле.
- **D-05:** `acquireKey()` async, блокирует до появления живого ключа. Если все заблокированы — ждёт разблокировки ближайшего. Таймаут ожидания: 10 минут → `AllKeysBlockedException`.
- **D-06:** `RateLimitException` получает поле `retryAfterSeconds: int` (default 60). `GroqApiService` парсит заголовки: `retry-after` → `x-ratelimit-reset-requests` (берём min) → fallback 60 с.
- **D-07:** Рекурсия `_processChunk` заменяется на while-loop с лимитом 10 попыток.
- **D-08:** Per-key статус: только зелёный "Активен" / красный "До HH:MM:SS". Квота в v1 не показывается.
- **D-09:** Обратный отсчёт через `Timer.periodic(1 s)` в виджете. Пул не нотифицирует каждую секунду.
- **D-10:** `ApiKeysScreen` → `ListenableBuilder(listenable: pool, ...)`.
- **D-11:** И `ChunkedTranscriptionController`, и `TranscriptionController` берут ключ через `pool.acquireKey()`.
- **D-12:** `maxConcurrent = min(pool.aliveKeyCount, kMaxConcurrentChunks)`. Константа `kMaxConcurrentChunks = 5`.

### Claude's Discretion

- Структура `KeyStatus` (value object или record) — на усмотрение реализации.
- Конкретный алгоритм round-robin (cyclic index vs shuffle).
- Нужен ли новый `ChunkWaitingForKey` state.

### Deferred Ideas (OUT OF SCOPE)

- Показ квоты (remaining-requests / remaining-tokens) — Phase 8.
- Персистентность статуса пула через рестарт.
- `ProcessingScreen` с per-key статусом во время транскрибации.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| KEYS-03 | Пользователь может удалить ключ из списка | Уже реализовано (`_confirmDelete` в `api_keys_screen.dart`) — только visual wire-up к пулу |
| KEYS-04 | Кликабельная ссылка на console.groq.com | Уже реализовано (`launchUrl` в `api_keys_screen.dart`) — без изменений |
| KEYS-05 | Статус ключа (активен / заблокирован до HH:MM:SS) | Новый виджет `_KeyStatusBadge` + `ListenableBuilder` + `Timer.periodic` |
| TRANS-01 | `GroqKeyPool`: round-robin, учёт RPM, блокировка при 429/503 | Новый класс `GroqKeyPool extends ChangeNotifier`; паттерн `_Semaphore` из chunked controller переиспользуется для `acquireKey()` |
| TRANS-02 | Длительность блокировки из заголовков Groq | Парсинг в `GroqApiService`: `retry-after` (секунды, int) → `x-ratelimit-reset-requests` (duration строка "2m59.56s") → fallback 60 |
</phase_requirements>

---

## Summary

Фаза добавляет `GroqKeyPool` — ChangeNotifier-сервис, инкапсулирующий round-robin ротацию нескольких Groq API-ключей и автоматическую блокировку при 429. Оба контроллера (chunked и single-shot) переходят с `keys.first.raw` на `pool.acquireKey()`. UI экрана ключей обновляется реактивно через `ListenableBuilder`.

**Ключевые изменения в существующем коде:**

1. `RateLimitException` — добавить поле `retryAfterSeconds: int`.
2. `GroqApiService.transcribeChunk()` — парсинг заголовков 429, бросать `RateLimitException` с секундами.
3. `ChunkedTranscriptionController` — заменить `ApiKeyRepository` на `GroqKeyPool`, while-loop вместо рекурсии, `maxConcurrent` динамически из пула.
4. `TranscriptionController` — аналогично, retry-loop при 429.
5. `AppConstants` — добавить `kMaxConcurrentChunks = 5`.
6. Новые файлы: `groq_key_pool.dart`, `key_status.dart`, `all_keys_blocked_exception.dart`.
7. `ApiKeysScreen` — добавить `ListenableBuilder` + `_KeyStatusBadge` + `Timer.periodic`.

**Риск 1 (MEDIUM):** Все ключи заблокированы одновременно — `acquireKey()` должен корректно ждать через `Timer` + Completer, а не busy-poll.

**Риск 2 (LOW):** `Timer.periodic` в виджете не отменён при `dispose()` — утечка. Обязательный `timer.cancel()` в `dispose()`.

**Primary recommendation:** Начать с `GroqKeyPool` + тестами, затем wire-up в контроллеры, UI — последним.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Хранение и CRUD ключей | `ApiKeyRepository` (storage layer) | `SecureStorageService` | Ключи хранятся в flutter_secure_storage; репозиторий — единственный потребитель |
| Ротация ключей и блокировка | `GroqKeyPool` (service layer) | — | Stateful: знает какой ключ живой, cyclic index, blockedUntil |
| Парсинг rate-limit заголовков | `GroqApiService` (network layer) | — | HTTP-ответ виден только здесь; конвертирует заголовки в `RateLimitException.retryAfterSeconds` |
| Retry-логика при 429 | `ChunkedTranscriptionController` / `TranscriptionController` | `GroqKeyPool` | Контроллеры вызывают `reportRateLimited` + повторный `acquireKey()`; пул знает следующий ключ |
| Реактивный UI статуса ключей | `ApiKeysScreen` (UI layer) | `GroqKeyPool` | `ListenableBuilder` слушает пул; `Timer.periodic` в виджете для countdown |
| Динамический concurrency | `ChunkedTranscriptionController` | `GroqKeyPool` | `maxConcurrent = min(pool.aliveKeyCount, kMaxConcurrentChunks)` |

---

## Standard Stack

### Core (уже в проекте)
| Library | Version | Purpose | Status |
|---------|---------|---------|--------|
| `flutter/foundation.dart` | SDK | `ChangeNotifier`, `notifyListeners` | В проекте |
| `dart:async` | SDK | `Timer`, `Completer`, `Future` | В проекте |
| `http` | ^1.x | HTTP-клиент для Groq | В проекте |

Новые пакеты не требуются. [VERIFIED: кодовая база проекта]

---

## Package Legitimacy Audit

Новые внешние пакеты не устанавливаются — фаза реализуется только на Dart SDK + уже имеющихся зависимостях.

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

---

## Architecture Patterns

### System Architecture Diagram

```
[ApiKeyRepository] ──listKeys()──► [GroqKeyPool: ChangeNotifier]
                                        │
                          ┌─────────────┼──────────────────┐
                          │             │                   │
                    acquireKey()  reportRateLimited()   getStatuses()
                          │             │                   │
                   [ChunkedTC]    [ChunkedTC / TC]   [ApiKeysScreen]
                   [TranscTC]           │               ListenableBuilder
                          │             │                   │
                   [GroqApiService]      │            [_KeyStatusBadge]
                    parse headers ───►  │            Timer.periodic(1s)
                    RateLimitException  │
                    .retryAfterSeconds──┘
```

### Recommended Project Structure
```
lib/
├── features/
│   ├── settings/
│   │   ├── api_key_repository.dart        # без изменений
│   │   └── groq_key_pool.dart             # НОВЫЙ
│   └── transcription/
│       ├── groq_api_service.dart          # парсинг заголовков 429
│       ├── chunked_transcription_controller.dart  # wire-up пула
│       └── transcription_controller.dart          # wire-up пула
├── core/
│   ├── constants/
│   │   └── app_constants.dart             # kMaxConcurrentChunks
│   └── error/
│       ├── app_exception.dart             # RateLimitException + retryAfterSeconds
│       └── all_keys_blocked_exception.dart  # НОВЫЙ
└── ui/
    └── screens/
        └── api_keys_screen.dart           # ListenableBuilder + _KeyStatusBadge

test/
├── features/
│   └── settings/
│       └── groq_key_pool_test.dart        # НОВЫЙ
└── unit/
    └── groq_api_service_rate_limit_test.dart  # НОВЫЙ
```

### Pattern 1: GroqKeyPool — acquireKey() через Completer-очередь

**Что:** Аналог `_Semaphore` из `chunked_transcription_controller.dart` — ждёт живого ключа через Completer.

**Когда использовать:** Когда все ключи заблокированы — не busy-poll, а подписка на ближайший `Timer`.

```dart
// [ASSUMED] — паттерн основан на _Semaphore из существующего кода проекта
class GroqKeyPool extends ChangeNotifier {
  final List<String> _keys;                    // сырые значения ключей
  final Map<String, DateTime> _blockedUntil = {}; // ключ → время разблокировки
  int _cyclicIndex = 0;                        // round-robin cursor
  final _waiters = <Completer<String>>[];       // очередь ожидающих acquireKey()

  // Количество живых ключей — для динамического semaphore в контроллере
  int get aliveKeyCount =>
      _keys.where((k) => !_isBlocked(k)).length;

  bool _isBlocked(String key) {
    final until = _blockedUntil[key];
    if (until == null) return false;
    if (DateTime.now().isAfter(until)) {
      _blockedUntil.remove(key);  // снимаем просроченную блокировку
      return false;
    }
    return true;
  }

  Future<String> acquireKey() async {
    final alive = _nextAlive();
    if (alive != null) return alive;

    // Все заблокированы — ждём ближайшей разблокировки
    final completer = Completer<String>();
    _waiters.add(completer);
    _scheduleWakeup();
    return completer.future.timeout(
      const Duration(minutes: 10),
      onTimeout: () => throw AllKeysBlockedException(),
    );
  }

  void _scheduleWakeup() {
    // Находим ближайший blockedUntil, ставим Timer
    final now = DateTime.now();
    final nearest = _blockedUntil.values
        .where((t) => t.isAfter(now))
        .fold<DateTime?>(null, (prev, t) =>
            prev == null || t.isBefore(prev) ? t : prev);
    if (nearest == null) return;
    final delay = nearest.difference(now);
    Timer(delay + const Duration(milliseconds: 50), _onWakeup);
  }

  void _onWakeup() {
    final alive = _nextAlive();
    if (alive == null) { _scheduleWakeup(); return; }
    // Отдаём ключ всем ожидающим (они сами разберутся через round-robin)
    while (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete(alive);
    }
    notifyListeners();
  }

  String? _nextAlive() {
    if (_keys.isEmpty) return null;
    // Cyclic index — обходим все ключи начиная с _cyclicIndex
    for (var i = 0; i < _keys.length; i++) {
      final idx = (_cyclicIndex + i) % _keys.length;
      if (!_isBlocked(_keys[idx])) {
        _cyclicIndex = (idx + 1) % _keys.length;  // advance cursor
        return _keys[idx];
      }
    }
    return null;
  }

  void reportRateLimited(String key, int retryAfterSeconds) {
    _blockedUntil[key] =
        DateTime.now().add(Duration(seconds: retryAfterSeconds));
    notifyListeners();  // UI обновится сразу
    _scheduleWakeup();  // разбудим waiters когда истечёт блокировка
  }

  List<KeyStatus> getStatuses() {
    return _keys.map((k) {
      final until = _blockedUntil[k];
      if (until != null && until.isAfter(DateTime.now())) {
        return KeyStatus.blocked(key: k, blockedUntil: until);
      }
      return KeyStatus.active(key: k);
    }).toList();
  }
}
```

### Pattern 2: KeyStatus — sealed class или Dart record

**Что:** Value object для per-key статуса.

```dart
// [ASSUMED] — паттерн sealed class уже используется в ChunkState
sealed class KeyStatus {
  final String key;         // raw key — для идентификации в UI (masked)
  const KeyStatus({required this.key});

  factory KeyStatus.active({required String key}) = _ActiveKeyStatus;
  factory KeyStatus.blocked({required String key, required DateTime blockedUntil})
      = _BlockedKeyStatus;
}

class _ActiveKeyStatus extends KeyStatus {
  const _ActiveKeyStatus({required super.key});
}

class _BlockedKeyStatus extends KeyStatus {
  final DateTime blockedUntil;
  const _BlockedKeyStatus({required super.key, required this.blockedUntil});
}
```

### Pattern 3: Парсинг заголовков 429 в GroqApiService

**Что:** `x-ratelimit-reset-requests` возвращает duration-строку вида `"2m59.56s"` или `"7.66s"`. `retry-after` — целые секунды (int-строка).

```dart
// [CITED: console.groq.com/docs/rate-limits]
// Формат x-ratelimit-reset-*: "2m59.56s", "45s", "1h2m3s"
int _parseRetryAfter(http.Response response) {
  // 1. retry-after (секунды, int)
  final ra = response.headers['retry-after'];
  if (ra != null) {
    final secs = int.tryParse(ra.trim());
    if (secs != null && secs > 0) return secs;
  }
  // 2. x-ratelimit-reset-requests (duration string)
  final resetReq = response.headers['x-ratelimit-reset-requests'];
  final resetTok = response.headers['x-ratelimit-reset-tokens'];
  final secsReq = resetReq != null ? _parseDurationString(resetReq) : null;
  final seksTok = resetTok != null ? _parseDurationString(resetTok) : null;

  // Берём минимум из двух (ограничивающий лимит истечёт первым)
  if (secsReq != null && seksTok != null) return secsReq < seksTok ? secsReq : seksTok;
  if (secsReq != null) return secsReq;
  if (seksTok != null) return seksTok;

  return 60; // fallback
}

// Парсит "2m59.56s" → 179, "45s" → 45, "1h2m3s" → 3723
int _parseDurationString(String s) {
  int total = 0;
  final hMatch = RegExp(r'(\d+)h').firstMatch(s);
  final mMatch = RegExp(r'(\d+)m').firstMatch(s);
  final sMatch = RegExp(r'([\d.]+)s').firstMatch(s);
  if (hMatch != null) total += int.parse(hMatch.group(1)!) * 3600;
  if (mMatch != null) total += int.parse(mMatch.group(1)!) * 60;
  if (sMatch != null) total += double.parse(sMatch.group(1)!).ceil();
  return total == 0 ? 60 : total;
}
```

### Pattern 4: while-loop в контроллере (замена рекурсии)

```dart
// [ASSUMED] — паттерн D-07 из CONTEXT.md
Future<void> _processChunk(int index, File file) async {
  _updateChunkState(index, ChunkUploading(index));
  final bytes = await file.readAsBytes();
  final filename = 'chunk_${index.toString().padLeft(3, '0')}.mp3';

  int attempt = 0;
  const maxAttempts = 10;

  while (attempt < maxAttempts) {
    final key = await _pool.acquireKey();  // ждёт живой ключ
    try {
      final result = await _api.transcribeChunk(
        bytes: bytes, filename: filename, apiKey: key,
      );
      _results[index] = result;
      _completedCount++;
      _updateChunkState(index, ChunkDone(index, text: result.text));
      return; // успех
    } on RateLimitException catch (e) {
      attempt++;
      _pool.reportRateLimited(key, e.retryAfterSeconds);
      _updateChunkState(index, ChunkRetrying(index, attempt: attempt));
      // НЕ ждём здесь — acquireKey() на следующей итерации сам заблокируется
    } on AuthException {
      rethrow; // не ретраить
    } on NetworkException {
      attempt++;
      if (attempt >= maxAttempts) rethrow;
      _updateChunkState(index, ChunkRetrying(index, attempt: attempt));
      await Future.delayed(Duration(seconds: 5 * (1 << (attempt - 1))));
    }
  }
  throw const NetworkException('Превышено максимальное число попыток');
}
```

### Pattern 5: _KeyStatusBadge с Timer.periodic

```dart
// [ASSUMED] — паттерн D-09 из CONTEXT.md
class _KeyStatusBadge extends StatefulWidget {
  final KeyStatus status;
  const _KeyStatusBadge({required this.status});

  @override
  State<_KeyStatusBadge> createState() => _KeyStatusBadgeState();
}

class _KeyStatusBadgeState extends State<_KeyStatusBadge> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.status is _BlockedKeyStatus) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();  // ОБЯЗАТЕЛЬНО — иначе утечка
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.status;
    if (s is _BlockedKeyStatus) {
      final remaining = s.blockedUntil.difference(DateTime.now());
      if (remaining.isNegative) {
        // Таймер ещё не сработал, но блокировка уже истекла
        return _activeBadge();
      }
      return _blockedBadge(_formatRemaining(remaining));
    }
    return _activeBadge();
  }

  String _formatRemaining(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Widget _activeBadge() => Row(children: [
    Icon(Icons.circle, size: 8, color: AppColors.good),
    const SizedBox(width: 4),
    Text('Активен', style: AppTextStyles.label),
  ]);

  Widget _blockedBadge(String countdown) => Row(children: [
    Icon(Icons.circle, size: 8, color: AppColors.bad),
    const SizedBox(width: 4),
    Text('До $countdown', style: AppTextStyles.label.copyWith(color: AppColors.bad)),
  ]);
}
```

### Anti-Patterns to Avoid

- **Busy-poll в acquireKey():** `while (true) { await Future.delayed(1s); ... }` — создаёт нагрузку и неточен. Использовать `Timer` + Completer.
- **notifyListeners() каждую секунду из пула:** Пул нотифицирует только при смене статуса (заблокирован/разблокирован). Countdown-виджет живёт отдельно.
- **_processChunk с рекурсией:** Может вызвать stack overflow при длинных блокировках. Заменить на while-loop (D-07).
- **Timer не отменён в dispose():** Классическая утечка во Flutter виджетах. Всегда `_timer?.cancel()` в `dispose()`.
- **_cyclicIndex без защиты:** Если ключи удалены из пула во время работы — `_cyclicIndex` выходит за пределы. Защита: `_cyclicIndex = _cyclicIndex % _keys.length` при каждом доступе, или сбрасывать при изменении списка.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Async ожидание ключа | Custom polling loop | `Completer<String>` + `Timer` | Точный wakeup, нет busy-wait; паттерн уже есть в `_Semaphore` |
| Парсинг duration-строки Groq | RegEx с нуля | `_parseDurationString` (см. Pattern 3) | Groq имеет нестандартный формат "2m59.56s" — нужен явный парсер |
| Countdown-таймер | Polling в `GroqKeyPool` | `Timer.periodic` в виджете | Пул должен быть UI-независим; виджет живёт/умирает независимо |

**Key insight:** Паттерн Completer-очереди уже реализован в `_Semaphore` (chunked_transcription_controller.dart) — `acquireKey()` — это тот же паттерн, только условие "есть свободный слот" заменяется на "есть живой ключ".

---

## Existing Code Analysis

### Что меняется в GroqApiService

**Текущее состояние:**
- `transcribeChunk({..., required String apiKey})` — ключ принимается параметром (хорошо).
- 429 → `throw const RateLimitException('Превышен лимит запросов Groq')` — без секунд.
- Заголовки `retry-after` / `x-ratelimit-reset-*` не читаются.

**Нужные изменения:**
1. В блоке `if (response.statusCode == 429)` — добавить вызов `_parseRetryAfter(response)` и бросать `RateLimitException` с секундами.
2. 503 — обрабатывать аналогично 429 (D-04 упоминает 503), или как `NetworkException` с `retryAfterSeconds = 60`.

### Что меняется в ChunkedTranscriptionController

**Текущее состояние:**
- Конструктор принимает `ApiKeyRepository keyRepository`.
- В `start()`: `final keys = await _keys.listKeys(); final apiKey = keys.first.raw;` — один ключ навсегда.
- `_semaphore = _Semaphore(maxConcurrent)` — статичный при создании.
- `_processChunk(index, file, apiKey)` — ключ передаётся один раз.

**Нужные изменения:**
1. Конструктор: заменить `ApiKeyRepository` на `GroqKeyPool`.
2. `start()`: убрать `listKeys()` + `keys.first.raw`. Проверку на пустой пул сделать через `pool.aliveKeyCount == 0 && pool.allKeys.isEmpty`.
3. `_processChunk` не принимает `apiKey` — берёт его сам через `pool.acquireKey()` на каждую попытку.
4. `_Semaphore` — создавать динамически или обновлять `maxConcurrent` перед запуском: `_semaphore = _Semaphore(min(pool.aliveKeyCount, kMaxConcurrentChunks))`.
5. `_withRetry` — заменить на while-loop в `_processChunk` (D-07); убрать `_withRetry` или сохранить только для NetworkException.

### Что меняется в TranscriptionController

**Текущее состояние:**
- Конструктор принимает `ApiKeyRepository keyRepository`.
- В `start()`: `keys.first.raw` — один ключ.
- Нет обработки `RateLimitException` — попадает в общий `catch`.

**Нужные изменения:**
1. Конструктор: заменить `ApiKeyRepository` на `GroqKeyPool`.
2. `start()` — добавить retry-loop при `RateLimitException`: вызвать `pool.reportRateLimited`, потом снова `pool.acquireKey()`.

### Что меняется в ApiKeysScreen

**Текущее состояние:**
- `StatefulWidget` создаёт `ApiKeyRepository` внутри.
- Список ключей — `List<ApiKeyView>`, обновляется через `_loadKeys()`.
- Нет подписки на пул.

**Нужные изменения:**
1. Добавить `GroqKeyPool` как параметр конструктора (или через `InheritedWidget`/провайдер).
2. Обернуть список ключей в `ListenableBuilder(listenable: pool, ...)`.
3. `_buildKeysList()` — добавить `_KeyStatusBadge` к каждой карточке ключа.
4. Логику добавления/удаления ключей синхронизировать с пулом (при добавлении — `pool.addKey(raw)`, при удалении — `pool.removeKey(raw)`).

### RateLimitException — добавить retryAfterSeconds

```dart
// [ASSUMED] — текущий AppException sealed class не имеет const с полями
class RateLimitException extends AppException {
  final int retryAfterSeconds;
  const RateLimitException(super.message, {this.retryAfterSeconds = 60});
}
```

**Осторожно:** sealed class `AppException` — нельзя добавить поле без сохранения совместимости `const`. Dart позволяет `const` конструктор с необязательным полем.

---

## Integration Points — Dependency Injection

`GroqKeyPool` создаётся в `main.dart` и передаётся вниз:

```dart
// [ASSUMED]
// main.dart
final pool = GroqKeyPool(repository: apiKeyRepository);

// Передаётся в:
// - ApiKeysScreen(pool: pool)
// - ChunkedTranscriptionController(pool: pool, ...)
// - TranscriptionController(pool: pool, ...)
```

Паттерн DI через конструктор уже используется в проекте — менять не нужно. Нет необходимости в `Provider` или `InheritedWidget` если `main.dart` передаёт пул при навигации (текущий паттерн проекта).

**Вопрос:** как сейчас контроллеры передаются в ProcessingScreen? Нужно уточнить при планировании — вероятно через Navigator arguments или StatefulWidget выше.

---

## Common Pitfalls

### Pitfall 1: Cyclic index выходит за пределы при динамическом изменении ключей
**Что идёт не так:** Пользователь удаляет ключ во время транскрибации → `_cyclicIndex` указывает за пределы `_keys`.
**Почему:** `_cyclicIndex` не сбрасывается при изменении списка.
**Как избежать:** При каждом обращении: `_cyclicIndex = _cyclicIndex % _keys.length` (если `_keys.isEmpty` — отдельная проверка).
**Warning signs:** `RangeError` в логах во время транскрибации.

### Pitfall 2: Все waiters получают один ключ при wakeup
**Что идёт не так:** Несколько чанков ждут ключа. Разблокировка одного ключа → все Completer завершаются с одним ключом → round-robin нарушается.
**Почему:** Простой `_waiters.forEach((c) => c.complete(alive))` не учитывает, что ключ может быть только один.
**Как избежать:** Отдавать ключ только первому waiter; остальные вызывают `acquireKey()` заново (или отдавать по одному, используя `_nextAlive()` для каждого).
**Warning signs:** Несколько чанков используют одинаковый ключ одновременно.

### Pitfall 3: Timer в виджете не отменён
**Что идёт не так:** `_KeyStatusBadge` анмаунтируется (ключ удалён), `Timer.periodic` продолжает работать → `setState()` на disposed widget → exception.
**Почему:** Flutter не отменяет Dart-таймеры автоматически.
**Как избежать:** `_timer?.cancel()` в `dispose()` — обязательно.
**Warning signs:** `setState() called after dispose()` в debug-консоли.

### Pitfall 4: x-ratelimit-reset-* может отсутствовать
**Что идёт не так:** Groq возвращает 429 без заголовков (или с другим набором заголовков).
**Почему:** Разные типы лимитов (RPM vs RPD) имеют разные наборы заголовков; возможны изменения API.
**Как избежать:** Всегда fallback 60с если ни один заголовок не распарсился.
**Warning signs:** Бесконечное ожидание в `acquireKey()`.

### Pitfall 5: GroqKeyPool инициализируется до загрузки ключей
**Что идёт не так:** `GroqKeyPool` создаётся в `main.dart` с пустым списком, ключи загружаются асинхронно — первая транскрибация видит пустой пул.
**Почему:** `flutter_secure_storage.listApiKeys()` — async; синхронный конструктор не может await.
**Как избежать:** `GroqKeyPool` имеет метод `reload()` который вызывается в `main.dart` после `await repository.listKeys()`, или конструктор принимает готовый `List<String> initialKeys`.
**Warning signs:** `ChunkedMissingKey` state при наличии ключей.

---

## Groq Rate Limit Headers Reference

[CITED: console.groq.com/docs/rate-limits]

| Заголовок | Тип значения | Пример | Присутствует когда |
|-----------|-------------|--------|-------------------|
| `retry-after` | int (секунды) | `"60"` | HTTP 429 |
| `x-ratelimit-limit-requests` | int | `"20"` | Всегда |
| `x-ratelimit-limit-tokens` | int | `"100000"` | Всегда |
| `x-ratelimit-remaining-requests` | int | `"19"` | Всегда |
| `x-ratelimit-remaining-tokens` | int | `"99000"` | Всегда |
| `x-ratelimit-reset-requests` | duration string | `"2m59.56s"` | Всегда |
| `x-ratelimit-reset-tokens` | duration string | `"7.66s"` | Всегда |

**Порядок парсинга (D-06):** `retry-after` → `min(x-ratelimit-reset-requests, x-ratelimit-reset-tokens)` → fallback 60.

**Формат duration string:** `"Xh"`, `"Xm"`, `"X.XXs"` или комбинация `"2m59.56s"`. Нестандартный (не ISO 8601), требует ручного парсинга.

---

## Runtime State Inventory

> Фаза не является rename/refactor. Секция включена для проверки state в памяти.

| Category | Items Found | Action Required |
|----------|-------------|-----------------|
| Stored data | `flutter_secure_storage`: список ключей без изменения формата | Без миграции — `GroqKeyPool.reload()` читает через `ApiKeyRepository.listKeys()` |
| Live service config | Нет | — |
| OS-registered state | Нет | — |
| Secrets/env vars | Groq API keys в flutter_secure_storage — структура не меняется | Без изменений |
| Build artifacts | Нет | — |

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK) |
| Config file | `flutter test` (нет отдельного файла) |
| Quick run command | `flutter test test/features/settings/groq_key_pool_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TRANS-01 | round-robin выдаёт ключи по очереди | unit | `flutter test test/features/settings/groq_key_pool_test.dart::round_robin` | ❌ Wave 0 |
| TRANS-01 | блокированный ключ пропускается | unit | `flutter test test/features/settings/groq_key_pool_test.dart::skip_blocked` | ❌ Wave 0 |
| TRANS-01 | все ключи заблокированы → ждём разблокировки | unit | `flutter test test/features/settings/groq_key_pool_test.dart::wait_for_unblock` | ❌ Wave 0 |
| TRANS-01 | таймаут 10 мин → AllKeysBlockedException | unit | `flutter test test/features/settings/groq_key_pool_test.dart::timeout_exception` | ❌ Wave 0 |
| TRANS-02 | парсинг retry-after (int) | unit | `flutter test test/unit/groq_api_service_rate_limit_test.dart::parse_retry_after` | ❌ Wave 0 |
| TRANS-02 | парсинг x-ratelimit-reset-requests ("2m59.56s") | unit | `flutter test test/unit/groq_api_service_rate_limit_test.dart::parse_duration_string` | ❌ Wave 0 |
| TRANS-02 | fallback 60с если заголовки отсутствуют | unit | `flutter test test/unit/groq_api_service_rate_limit_test.dart::fallback` | ❌ Wave 0 |
| KEYS-05 | UI показывает "Активен" для живого ключа | widget | `flutter test test/widget/api_keys_screen_status_test.dart` | ❌ Wave 0 |
| KEYS-05 | UI показывает "До HH:MM:SS" для заблокированного | widget | `flutter test test/widget/api_keys_screen_status_test.dart` | ❌ Wave 0 |

### Стратегия тестирования GroqKeyPool с fake timers

Flutter `flutter_test` предоставляет `FakeAsync` через пакет `fake_async` (уже в dev_dependencies flutter_test). Паттерн:

```dart
// [ASSUMED] — стандартный паттерн fake_async в Dart-тестах
import 'package:fake_async/fake_async.dart';

test('разблокировка через 60 секунд', () {
  fakeAsync((async) {
    final pool = GroqKeyPool(initialKeys: ['key1']);
    pool.reportRateLimited('key1', 60);

    // Сразу — ключ заблокирован
    expect(pool.aliveKeyCount, 0);

    // Переводим время на 61 секунду
    async.elapse(const Duration(seconds: 61));

    // Теперь ключ живой
    expect(pool.aliveKeyCount, 1);
  });
});
```

### Sampling Rate
- **Per task commit:** `flutter test test/features/settings/groq_key_pool_test.dart`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green перед `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/features/settings/groq_key_pool_test.dart` — покрывает TRANS-01
- [ ] `test/unit/groq_api_service_rate_limit_test.dart` — покрывает TRANS-02
- [ ] `test/widget/api_keys_screen_status_test.dart` — покрывает KEYS-05

---

## Environment Availability

> Фаза не требует новых внешних инструментов.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | Всё | ✓ | В проекте | — |
| `flutter_secure_storage` | ApiKeyRepository | ✓ | В проекте | — |
| `fake_async` | Тесты GroqKeyPool | ✓ | Входит в flutter_test | — |

---

## Security Domain

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | API-ключи только в flutter_secure_storage (CLAUDE.md) |
| V5 Input Validation | yes | `ApiKeyRepository.addKey()` валидирует минимальную длину 20 |
| V6 Cryptography | no | Шифрование delegated to flutter_secure_storage |

**Не передавать ключ в логи:** При реализации `reportRateLimited(key, seconds)` и логах — маскировать ключ как `key.substring(key.length - 4)` или использовать `ApiKeyRepository.mask()`.

---

## Open Questions

1. **Как GroqKeyPool получает актуальный список ключей при добавлении/удалении через ApiKeysScreen?**
   - Что знаем: `ApiKeysScreen` использует `ApiKeyRepository` напрямую для add/delete.
   - Что неясно: Нужен ли метод `pool.reload()` после каждого add/delete, или пул сам наблюдает за репозиторием?
   - Рекомендация: Проще всего — `ApiKeysScreen` вызывает `pool.addKey(raw)` / `pool.removeKey(raw)` напрямую. Пул становится source of truth; репозиторий — только персистенция.

2. **Как контроллеры сейчас получают зависимости?**
   - Что знаем: DI через конструктор используется в проекте.
   - Что неясно: Создаются ли контроллеры в `main.dart` или при переходе на экран?
   - Рекомендация: Проверить `main.dart` или маршрутизацию при планировании.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `_parseDurationString` для формата "2m59.56s" | Pattern 3 | Groq использует другой формат → парсинг вернёт fallback 60с |
| A2 | `fake_async` доступен в flutter_test без доп. зависимостей | Validation | Может потребоваться отдельный `dev_dependency: fake_async` |
| A3 | Конструктор `GroqKeyPool(initialKeys: List<String>)` — синхронная инициализация | Pitfall 5 | Если async — нужен `GroqKeyPool.create()` factory |
| A4 | Передача пула через конструктор достаточна (не нужен Provider) | Integration | Если дерево виджетов глубокое — может потребоваться InheritedWidget |
| A5 | `AppColors.good` существует в design_tokens.dart | Pattern 5 (UI) | Другое имя → compile error |

---

## Sources

### Primary (HIGH confidence)
- Кодовая база проекта (`lib/features/transcription/`, `lib/core/`) — прочитано напрямую
- `04-CONTEXT.md` — locked decisions D-01...D-12

### Secondary (MEDIUM confidence)
- [Groq Rate Limits docs](https://console.groq.com/docs/rate-limits) — формат заголовков (WebSearch, не WebFetch)
- `_Semaphore` паттерн из `chunked_transcription_controller.dart` — прямо в коде

### Tertiary (LOW confidence)
- Формат "2m59.56s" для `x-ratelimit-reset-*` — WebSearch (не верифицировано через официальную doc напрямую)

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — только SDK, новых пакетов нет
- GroqKeyPool design: HIGH — locked decisions из CONTEXT.md
- Groq headers format: MEDIUM — WebSearch + community confirmed, doc страница недоступна через fetch
- Test patterns: HIGH — существующий код проекта

**Research date:** 2026-05-17
**Valid until:** 2026-06-17 (Groq API headers stable, Flutter SDK stable)
