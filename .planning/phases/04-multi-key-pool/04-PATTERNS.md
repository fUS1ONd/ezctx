# Phase 4: Multi-Key Pool & Rate-Limit UI — Pattern Map

**Mapped:** 2026-05-17
**Files analyzed:** 9 (6 основных + 3 вспомогательных)
**Analogs found:** 9 / 9

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/features/transcription/groq_key_pool.dart` | service | event-driven | `chunked_transcription_controller.dart` (`_Semaphore`) | role-match |
| `lib/core/error/all_keys_blocked_exception.dart` | model | — | `lib/core/error/app_exception.dart` | exact |
| `lib/features/transcription/groq_api_service.dart` | service | request-response | само себе (MODIFY) | exact |
| `lib/features/transcription/chunked_transcription_controller.dart` | service | event-driven | само себе (MODIFY) | exact |
| `lib/features/transcription/transcription_controller.dart` | service | request-response | само себе (MODIFY) | exact |
| `lib/features/transcription/chunk_state.dart` | model | — | само себе (MODIFY) | exact |
| `lib/core/constants/app_constants.dart` | config | — | само себе (MODIFY) | exact |
| `lib/ui/screens/api_keys_screen.dart` | component | request-response | само себе (MODIFY) | exact |
| `lib/ui/widgets/key_status_tile.dart` | component | event-driven | `lib/ui/screens/api_keys_screen.dart` `_buildKeysList` + `GlassCard` | role-match |

---

## Pattern Assignments

### `lib/features/transcription/groq_key_pool.dart` (service, event-driven, НОВЫЙ)

**Аналог:** `lib/features/transcription/chunked_transcription_controller.dart` — паттерн `_Semaphore` (строки 18–39) и `ChangeNotifier` + `_set`/`notifyListeners` (строки 104–135).

**Imports pattern** (копировать из chunked_transcription_controller.dart, строки 1–12):
```dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../settings/api_key_repository.dart';
```

**ChangeNotifier + notifyListeners pattern** (chunked_transcription_controller.dart, строки 104–135):
```dart
class ChunkedTranscriptionController extends ChangeNotifier {
  // ...
  void _set(ChunkedState s) {
    _state = s;
    notifyListeners();
  }
}
```
`GroqKeyPool` использует тот же паттерн: `notifyListeners()` вызывается в `reportRateLimited()` и в `_onWakeup()` — только при смене статуса, не каждую секунду.

**Completer-queue pattern** (chunked_transcription_controller.dart, строки 18–39 — `_Semaphore`):
```dart
class _Semaphore {
  _Semaphore(this._maxConcurrent);
  final int _maxConcurrent;
  int _running = 0;
  final _queue = <Completer<void>>[];

  Future<T> run<T>(Future<T> Function() fn) async {
    if (_running >= _maxConcurrent) {
      final waiter = Completer<void>();
      _queue.add(waiter);
      await waiter.future;          // <-- блокируется до освобождения слота
    }
    _running++;
    try {
      return await fn();
    } finally {
      _running--;
      if (_queue.isNotEmpty) _queue.removeAt(0).complete(); // будит следующего
    }
  }
}
```
`GroqKeyPool.acquireKey()` реализует аналогичный паттерн: вместо `_running >= _maxConcurrent` проверяется `_nextAlive() == null`; вместо `_queue.removeAt(0).complete()` в finally — `Timer` будит ожидающих при истечении блокировки ближайшего ключа.

**Core алгоритм GroqKeyPool** (основан на RESEARCH.md Pattern 1 — VERIFIED против `_Semaphore`):
```dart
// Основные поля
final List<String> _keys;
final Map<String, DateTime> _blockedUntil = {};
int _cyclicIndex = 0;
final _waiters = <Completer<String>>[];

// acquireKey() — аналог _Semaphore.run(), но условие "живой ключ"
Future<String> acquireKey() async {
  final alive = _nextAlive();
  if (alive != null) return alive;
  final completer = Completer<String>();
  _waiters.add(completer);
  _scheduleWakeup();
  return completer.future.timeout(
    const Duration(minutes: 10),
    onTimeout: () => throw const AllKeysBlockedException(),
  );
}

// reportRateLimited() — вызывается контроллером при 429
void reportRateLimited(String key, int retryAfterSeconds) {
  _blockedUntil[key] = DateTime.now().add(Duration(seconds: retryAfterSeconds));
  notifyListeners();   // UI обновляется мгновенно
  _scheduleWakeup();   // будим waiters при разблокировке
}
```

**Pitfall: cyclic index out of bounds** (RESEARCH.md Pitfall 1):
```dart
// ВСЕГДА защищать _cyclicIndex при любом обращении к _keys
String? _nextAlive() {
  if (_keys.isEmpty) return null;
  for (var i = 0; i < _keys.length; i++) {
    final idx = (_cyclicIndex + i) % _keys.length;  // защита от выхода за пределы
    if (!_isBlocked(_keys[idx])) {
      _cyclicIndex = (idx + 1) % _keys.length;
      return _keys[idx];
    }
  }
  return null;
}
```

---

### `lib/core/error/all_keys_blocked_exception.dart` (model, НОВЫЙ)

**Аналог:** `lib/core/error/app_exception.dart` (строки 1–34) — паттерн sealed class + const конструктор.

**Exception pattern** (app_exception.dart, строки 1–9 + 32–34):
```dart
sealed class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

/// HTTP 429 от Groq — превышен rate limit; ретраится с задержкой.
class RateLimitException extends AppException {
  const RateLimitException(super.message);
}
```
`AllKeysBlockedException` следует тому же паттерну: `class AllKeysBlockedException extends AppException` с `const` конструктором. НЕ является `sealed` (это конечный класс).

---

### `lib/core/error/app_exception.dart` (model, MODIFY)

**Изменение:** добавить поле `retryAfterSeconds: int` в `RateLimitException`.

**Текущее состояние** (app_exception.dart, строки 32–34):
```dart
class RateLimitException extends AppException {
  const RateLimitException(super.message);
}
```

**Target pattern** — добавить необязательное поле с дефолтом (Dart позволяет `const` конструктор с необязательным параметром):
```dart
class RateLimitException extends AppException {
  final int retryAfterSeconds;
  const RateLimitException(super.message, {this.retryAfterSeconds = 60});
}
```
Обратная совместимость сохраняется: все существующие `const RateLimitException('...')` продолжают компилироваться.

---

### `lib/features/transcription/groq_api_service.dart` (service, request-response, MODIFY)

**Изменение:** добавить парсинг заголовков 429 и передавать `retryAfterSeconds` в `RateLimitException`.

**Текущий 429-блок** (groq_api_service.dart, строки 74–76):
```dart
if (response.statusCode == 429) {
  throw const RateLimitException('Превышен лимит запросов Groq');
}
```

**Target pattern** — заменить на:
```dart
if (response.statusCode == 429) {
  throw RateLimitException(
    'Превышен лимит запросов Groq',
    retryAfterSeconds: _parseRetryAfter(response),
  );
}
```

**Добавить приватные методы** (RESEARCH.md Pattern 3 — формат заголовков Groq):
```dart
// Порядок: retry-after → min(x-ratelimit-reset-requests, x-ratelimit-reset-tokens) → 60
int _parseRetryAfter(http.Response response) {
  final ra = response.headers['retry-after'];
  if (ra != null) {
    final secs = int.tryParse(ra.trim());
    if (secs != null && secs > 0) return secs;
  }
  final secsReq = response.headers['x-ratelimit-reset-requests'] != null
      ? _parseDurationString(response.headers['x-ratelimit-reset-requests']!)
      : null;
  final secsTok = response.headers['x-ratelimit-reset-tokens'] != null
      ? _parseDurationString(response.headers['x-ratelimit-reset-tokens']!)
      : null;
  if (secsReq != null && secsTok != null) return secsReq < secsTok ? secsReq : secsTok;
  if (secsReq != null) return secsReq;
  if (secsTok != null) return secsTok;
  return 60; // fallback — всегда ненулевой
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

**Импорты:** `http` уже импортирован (строка 5). Новых зависимостей нет.

---

### `lib/features/transcription/chunked_transcription_controller.dart` (service, event-driven, MODIFY)

**Изменения:**
1. Конструктор: `ApiKeyRepository keyRepository` → `GroqKeyPool pool`.
2. `start()`: убрать `_keys.listKeys()` / `keys.first.raw`; пустой пул через `pool.allKeys.isEmpty`.
3. `_semaphore` создаётся динамически: `_Semaphore(min(pool.aliveKeyCount, kMaxConcurrentChunks))`.
4. `_processChunk` больше не принимает `apiKey` — берёт через `pool.acquireKey()` в while-loop.
5. `_withRetry` заменяется на inline while-loop в `_processChunk` (D-07, max 10 попыток).

**Текущий конструктор** (chunked_transcription_controller.dart, строки 105–113):
```dart
ChunkedTranscriptionController({
  required ApiKeyRepository keyRepository,
  required GroqApiService apiService,
  required AudioChunkingService chunkingService,
  int maxConcurrent = 3,
})  : _keys = keyRepository,
      _api = apiService,
      _chunkingService = chunkingService,
      _semaphore = _Semaphore(maxConcurrent);
```

**Target конструктор:**
```dart
ChunkedTranscriptionController({
  required GroqKeyPool pool,
  required GroqApiService apiService,
  required AudioChunkingService chunkingService,
})  : _pool = pool,
      _api = apiService,
      _chunkingService = chunkingService;
```
Семафор создаётся в `start()` непосредственно перед `Future.wait`, чтобы взять актуальный `pool.aliveKeyCount`.

**Текущий блок `start()` для ключа** (строки 155–160):
```dart
final keys = await _keys.listKeys();
if (keys.isEmpty) {
  _set(const ChunkedMissingKey());
  return;
}
final apiKey = keys.first.raw;
```

**Target блок:**
```dart
if (_pool.allKeys.isEmpty) {
  _set(const ChunkedMissingKey());
  return;
}
final semaphore = _Semaphore(
  min(_pool.aliveKeyCount.clamp(1, kMaxConcurrentChunks), kMaxConcurrentChunks),
);
```

**Текущий `_processChunk`** (строки 233–256):
```dart
Future<void> _processChunk(int index, File file, String apiKey) async {
  _updateChunkState(index, ChunkUploading(index));
  final bytes = await file.readAsBytes();
  final filename = 'chunk_${index.toString().padLeft(3, '0')}.mp3';
  final result = await _withRetry(
    () => _api.transcribeChunk(bytes: bytes, filename: filename, apiKey: apiKey),
    index,
  );
  _results[index] = result;
  // ...
}
```

**Target `_processChunk`** — while-loop (D-07), аналог `_withRetry` из строк 262–286:
```dart
Future<void> _processChunk(int index, File file) async {
  _updateChunkState(index, ChunkUploading(index));
  final bytes = await file.readAsBytes();
  final filename = 'chunk_${index.toString().padLeft(3, '0')}.mp3';

  int attempt = 0;
  const maxAttempts = 10;
  while (attempt < maxAttempts) {
    final key = await _pool.acquireKey();
    try {
      final result = await _api.transcribeChunk(
        bytes: bytes, filename: filename, apiKey: key,
      );
      _results[index] = result;
      _completedCount++;
      _updateChunkState(index, ChunkDone(index, text: result.text));
      return;
    } on RateLimitException catch (e) {
      attempt++;
      _pool.reportRateLimited(key, e.retryAfterSeconds);
      _updateChunkState(index, ChunkRetrying(index, attempt: attempt));
      // НЕ ждём — acquireKey() на следующей итерации сам заблокируется
    } on AuthException {
      rethrow;
    } on NetworkException {
      attempt++;
      if (attempt >= maxAttempts) rethrow;
      _updateChunkState(index, ChunkRetrying(index, attempt: attempt));
      await Future.delayed(Duration(seconds: 5 * (1 << (attempt - 1).clamp(0, 5))));
    }
  }
  throw const NetworkException('Превышено максимальное число попыток');
}
```

---

### `lib/features/transcription/transcription_controller.dart` (service, request-response, MODIFY)

**Изменения:**
1. Конструктор: `ApiKeyRepository keyRepository` → `GroqKeyPool pool`.
2. `start()`: `keys.first.raw` → `pool.acquireKey()`; добавить retry-loop при `RateLimitException`.

**Текущий конструктор** (transcription_controller.dart, строки 39–44):
```dart
TranscriptionController({
  required ApiKeyRepository keyRepository,
  required GroqApiService apiService,
})  : _keys = keyRepository,
      _api = apiService;
```

**Текущий `start()` блок** (строки 67–88):
```dart
Future<void> start(SelectedAudioFile file) async {
  _set(const TranscriptionLoading());
  final keys = await _keys.listKeys();
  if (keys.isEmpty) {
    _set(const TranscriptionMissingKey());
    return;
  }
  try {
    final result = await _api.transcribe(file: file, apiKey: keys.first.raw);
    _set(TranscriptionSuccess(result));
  } on AuthException catch (e) {
    _set(TranscriptionError(e.message, retryable: false));
  } on NetworkException catch (e) {
    _set(TranscriptionError(e.message, retryable: true));
  } on InternalException catch (e) {
    _set(TranscriptionError(e.message, retryable: true));
  } catch (_) {
    _set(TranscriptionError('Неизвестная ошибка', retryable: true));
  }
}
```

**Target start()** — добавить retry при `RateLimitException`:
```dart
Future<void> start(SelectedAudioFile file) async {
  _set(const TranscriptionLoading());
  if (_pool.allKeys.isEmpty) {
    _set(const TranscriptionMissingKey());
    return;
  }
  int attempt = 0;
  const maxAttempts = 10;
  try {
    while (attempt < maxAttempts) {
      final key = await _pool.acquireKey();
      try {
        final result = await _api.transcribe(file: file, apiKey: key);
        _set(TranscriptionSuccess(result));
        return;
      } on RateLimitException catch (e) {
        attempt++;
        _pool.reportRateLimited(key, e.retryAfterSeconds);
        // acquireKey() на следующей итерации заблокируется если нужно
      }
    }
    _set(const TranscriptionError('Превышено число попыток', retryable: true));
  } on AllKeysBlockedException {
    _set(const TranscriptionError('Все ключи заблокированы. Подождите и повторите.', retryable: true));
  } on AuthException catch (e) {
    _set(TranscriptionError(e.message, retryable: false));
  } on NetworkException catch (e) {
    _set(TranscriptionError(e.message, retryable: true));
  } on InternalException catch (e) {
    _set(TranscriptionError(e.message, retryable: true));
  } catch (_) {
    _set(const TranscriptionError('Неизвестная ошибка', retryable: true));
  }
}
```

**Паттерн `_disposed` guard** — сохранить без изменений (transcription_controller.dart, строки 48–64):
```dart
bool _disposed = false;

@override
void dispose() {
  _disposed = true;
  super.dispose();
}

void _set(TranscriptionState s) {
  if (_disposed) return;    // защита от notifyListeners() после dispose()
  _state = s;
  notifyListeners();
}
```

---

### `lib/features/transcription/chunk_state.dart` (model, MODIFY — опционально)

**Текущий паттерн** (chunk_state.dart, строки 1–40) — sealed class с `index` и `label`:
```dart
sealed class ChunkState {
  final int index;
  final String label;
  const ChunkState({required this.index, required this.label});
}

class ChunkWaiting extends ChunkState {
  const ChunkWaiting(int index)
      : super(index: index, label: 'Часть ${index + 1}: ожидание');
}
```

**Если добавляем `ChunkWaitingForKey`** — следовать тому же паттерну:
```dart
/// Чанк ожидает свободного ключа из пула (все ключи временно заблокированы).
class ChunkWaitingForKey extends ChunkState {
  const ChunkWaitingForKey(int index)
      : super(index: index, label: 'Часть ${index + 1}: ожидание ключа...');
}
```

---

### `lib/core/constants/app_constants.dart` (config, MODIFY)

**Текущий паттерн** (app_constants.dart, строки 1–47) — `class AppConstants` с `static const`.

**Добавить** после `kChunkDurationSeconds` (строка 36):
```dart
/// Максимальное число параллельных чанков; реальное значение = min(pool.aliveKeyCount, этой константы).
static const int kMaxConcurrentChunks = 5;
```

---

### `lib/ui/screens/api_keys_screen.dart` (component, request-response, MODIFY)

**Изменения:**
1. Добавить `GroqKeyPool pool` как параметр конструктора.
2. Обернуть `_buildKeysList()` в `ListenableBuilder(listenable: pool, ...)`.
3. В `_confirmDelete` и `_onAddPressed` синхронизировать пул: `pool.removeKey(raw)` / `pool.addKey(raw)`.
4. Добавить `KeyStatusTile` (или `_KeyStatusBadge`) внутри карточки ключа.

**Текущий конструктор** (api_keys_screen.dart, строки 16–21):
```dart
class ApiKeysScreen extends StatefulWidget {
  const ApiKeysScreen({super.key});
```

**Target конструктор:**
```dart
class ApiKeysScreen extends StatefulWidget {
  const ApiKeysScreen({super.key, required this.pool});
  final GroqKeyPool pool;
```

**Текущий `_buildKeysList` — карточка ключа** (строки 111–139):
```dart
return Column(
  children: _keys.map((key) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(Icons.vpn_key_outlined, size: 24, color: AppColors.inkSecondary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(key.masked, style: AppTextStyles.mono)),
            Semantics(
              label: 'Удалить ключ',
              button: true,
              child: IconButton(
                icon: const Icon(Icons.delete_outline),
                color: AppColors.bad,
                onPressed: () => _confirmDelete(key),
              ),
            ),
          ],
        ),
      ),
    );
  }).toList(),
);
```

**Target** — добавить статус-виджет между `Expanded(masked)` и `IconButton(delete)`:
```dart
// Между Expanded(key.masked) и IconButton добавить:
KeyStatusTile(status: widget.pool.getStatusForKey(key.raw)),
```

**ListenableBuilder pattern** (D-10 из CONTEXT.md):
```dart
// Оборачиваем _buildKeysList() в ListenableBuilder:
ListenableBuilder(
  listenable: widget.pool,
  builder: (context, _) => _buildKeysList(),
)
```

---

### `lib/ui/widgets/key_status_tile.dart` (component, event-driven, НОВЫЙ)

**Аналог:** `lib/ui/screens/api_keys_screen.dart` — паттерн `GlassCard` + `Row` + `AppColors.good`/`bad` (строки 111–139). Паттерн `StatefulWidget` с `Timer.periodic` в `initState` + `cancel()` в `dispose()` — стандартный Flutter.

**Imports pattern** (аналог api_keys_screen.dart, строки 1–10):
```dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/design_tokens.dart';
import '../../features/transcription/groq_key_pool.dart'; // KeyStatus
```

**StatefulWidget + Timer.periodic pattern** (D-09 из CONTEXT.md — VERIFIED против Flutter best practices):
```dart
class KeyStatusTile extends StatefulWidget {
  const KeyStatusTile({super.key, required this.status});
  final KeyStatus status;

  @override
  State<KeyStatusTile> createState() => _KeyStatusTileState();
}

class _KeyStatusTileState extends State<KeyStatusTile> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Запускаем тикер только для заблокированных ключей
    if (widget.status is BlockedKeyStatus) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void didUpdateWidget(KeyStatusTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Пересоздаём тикер при смене типа статуса
    if (widget.status.runtimeType != oldWidget.status.runtimeType) {
      _timer?.cancel();
      _timer = null;
      if (widget.status is BlockedKeyStatus) {
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() {});
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();   // ОБЯЗАТЕЛЬНО — иначе утечка (RESEARCH.md Pitfall 3)
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.status;
    if (s is BlockedKeyStatus) {
      final remaining = s.blockedUntil.difference(DateTime.now());
      if (remaining.isNegative) return _activeBadge();
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
    Icon(Icons.circle, size: 8, color: AppColors.good),   // AppColors.good = 0xFF2DB585
    const SizedBox(width: AppSpacing.xs),
    Text('Активен', style: AppTextStyles.label),
  ]);

  Widget _blockedBadge(String countdown) => Row(children: [
    Icon(Icons.circle, size: 8, color: AppColors.bad),    // AppColors.bad = 0xFFE0395A
    const SizedBox(width: AppSpacing.xs),
    Text(
      'До $countdown',
      style: AppTextStyles.label.copyWith(color: AppColors.bad),
    ),
  ]);
}
```

---

## Shared Patterns

### ChangeNotifier + notifyListeners
**Источник:** `lib/features/transcription/chunked_transcription_controller.dart`, строки 104–135
**Применять к:** `groq_key_pool.dart`
```dart
class GroqKeyPool extends ChangeNotifier {
  void reportRateLimited(String key, int retryAfterSeconds) {
    // ... обновляем состояние ...
    notifyListeners();  // UI обновляется мгновенно
  }
}
```

### Sealed class + const конструктор
**Источник:** `lib/core/error/app_exception.dart` (строки 1–34) и `lib/features/transcription/chunk_state.dart` (строки 1–40)
**Применять к:** `KeyStatus` в `groq_key_pool.dart`, `AllKeysBlockedException`
```dart
sealed class KeyStatus {
  final String key;
  const KeyStatus({required this.key});
}

class ActiveKeyStatus extends KeyStatus {
  const ActiveKeyStatus({required super.key});
}

class BlockedKeyStatus extends KeyStatus {
  final DateTime blockedUntil;
  const BlockedKeyStatus({required super.key, required this.blockedUntil});
}
```

### GlassCard карточка ключа
**Источник:** `lib/ui/screens/api_keys_screen.dart`, строки 111–139
**Применять к:** `key_status_tile.dart` (встраивается внутрь существующей GlassCard, не создаёт новую)
```dart
GlassCard(
  padding: const EdgeInsets.symmetric(
    horizontal: AppSpacing.md,
    vertical: AppSpacing.sm,
  ),
  child: Row(children: [
    Icon(Icons.vpn_key_outlined, size: 24, color: AppColors.inkSecondary),
    const SizedBox(width: AppSpacing.sm),
    Expanded(child: Text(key.masked, style: AppTextStyles.mono)),
    // НОВОЕ:
    KeyStatusTile(status: pool.getStatusForKey(key.raw)),
    IconButton(/* удалить */),
  ]),
)
```

### Dependency injection через конструктор
**Источник:** `lib/features/transcription/chunked_transcription_controller.dart` (строки 105–113), `lib/features/transcription/transcription_controller.dart` (строки 39–44)
**Применять к:** всем модифицируемым классам
Нет глобальных синглтонов в коде. `GroqKeyPool` создаётся в `main.dart` и передаётся явно через конструктор.

### AppColors токены
**Источник:** `lib/core/constants/design_tokens.dart`, строки 4–24
**Применять к:** `key_status_tile.dart`
- `AppColors.good = Color(0xFF2DB585)` — зелёный индикатор "Активен"
- `AppColors.bad = Color(0xFFE0395A)` — красный индикатор "Заблокирован"
- `AppColors.inkSecondary` — иконки ключей

---

## No Analog Found

Нет файлов без аналога — все паттерны покрыты существующим кодом проекта.

---

## Metadata

**Analog search scope:** `lib/features/transcription/`, `lib/core/error/`, `lib/core/constants/`, `lib/ui/screens/`, `lib/ui/widgets/`, `lib/features/settings/`
**Files scanned:** 8 файлов прочитано напрямую
**Pattern extraction date:** 2026-05-17
