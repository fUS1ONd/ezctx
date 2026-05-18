---
phase: 04-multi-key-pool
reviewed: 2026-05-18T00:00:00Z
depth: standard
files_reviewed: 17
files_reviewed_list:
  - lib/core/constants/app_constants.dart
  - lib/core/error/all_keys_blocked_exception.dart
  - lib/core/error/app_exception.dart
  - lib/features/transcription/chunk_state.dart
  - lib/features/transcription/chunked_transcription_controller.dart
  - lib/features/transcription/groq_api_service.dart
  - lib/features/transcription/groq_key_pool.dart
  - lib/features/transcription/transcription_controller.dart
  - lib/main.dart
  - lib/ui/app.dart
  - lib/ui/screens/api_keys_screen.dart
  - lib/ui/screens/processing_screen.dart
  - lib/ui/widgets/chunk_tile.dart
  - lib/ui/widgets/key_status_tile.dart
  - test/features/settings/groq_key_pool_test.dart
  - test/unit/groq_api_service_rate_limit_test.dart
  - test/widget/api_keys_screen_status_test.dart
findings:
  critical: 4
  warning: 6
  info: 3
  total: 13
status: issues_found
---

# Phase 04: Code Review Report

**Reviewed:** 2026-05-18T00:00:00Z
**Depth:** standard
**Files Reviewed:** 17
**Status:** issues_found

## Summary

Reviewed the Phase 4 implementation: GroqKeyPool (multi-key round-robin with rate-limit blacklisting), migration of transcription controllers to use the pool, and the reactive key status UI. The architecture is sound and the separation of concerns is reasonable. However, four critical defects were found: a waiter starvation bug in the key pool's wakeup logic that can deliver the same key to multiple waiters; a double-setState call in `_onChunkedStateChange` that causes redundant rebuilds and a potential crash after navigation; incorrect use of `DateTime.now()` instead of `clock.now()` in `KeyStatusTile` breaking testability and causing drift against pool timestamps; and a missing `await` on `_chunkedController!.start()` in ProcessingScreen that silently drops all errors from the chunked pipeline. There are also several correctness warnings around `_completedCount` mutation from concurrent futures without synchronisation, dead code in the chunked controller, and an incorrect test comment.

---

## Critical Issues

### CR-01: Key pool wakeup distributes same key to multiple concurrent waiters

**File:** `lib/features/transcription/groq_key_pool.dart:113-121`

**Issue:** `_onWakeup()` calls `_nextAlive()` in a tight `while` loop and hands the returned key to each waiter in sequence. `_nextAlive()` does advance `_cyclicIndex` after each call, but the same single live key can be returned for every waiting call when only one key has just unblocked. Specifically: if `_keys = ['k1']` and 3 waiters are queued, all three receive `'k1'` in the same microtask turn because `_isBlocked` re-checks `clock.now()` which has not advanced. All three concurrent HTTP requests then fire on the same key simultaneously, causing immediate 429s and re-blocking the key. This is both a correctness bug (rate-limit storm) and a liveness issue (the pool re-blocks itself on every wakeup when there is only one key).

**Fix:** Distribute at most one key per live slot. After resolving a waiter, re-check whether a new alive key exists before resolving the next:

```dart
void _onWakeup() {
  if (_waiters.isEmpty) return;
  // Resolve waiters one-by-one; stop as soon as no alive key is available.
  while (_waiters.isNotEmpty) {
    final alive = _nextAlive();
    if (alive == null) {
      _scheduleWakeup();
      break;
    }
    // Remove exactly one waiter and give it this key.
    // Do NOT loop back immediately — acquireKey callers will call back if they need more.
    _waiters.removeAt(0).complete(alive);
    // After completing one waiter, break out so the event loop can run
    // and the waiter can actually use the key before we hand it out again.
    break;
  }
  notifyListeners();
}
```

Alternatively, model key slots explicitly (a counting semaphore per key) so that concurrent use is bounded.

---

### CR-02: `_completedCount` incremented concurrently without synchronisation

**File:** `lib/features/transcription/chunked_transcription_controller.dart:274-280`

**Issue:** `_processChunk` runs inside `Future.wait`, meaning multiple instances execute concurrently. Each successful chunk does `_completedCount++` (line 275) and then reads `_chunkStates.length` while other futures may be mutating `_chunkStates[index]` simultaneously. Dart's event loop is single-threaded so this is not a data-race in the C++ sense, but because each future can yield at `await` points, the sequence:

1. Future A reads `_completedCount` (= 2), increments → 3
2. Future B (already past its `await`) reads `_completedCount` (= 3), increments → 4
3. Future A then calls `_set(ChunkedProcessing(completedCount: 3, ...))` — already stale

is entirely possible. The result is that the UI may show a lower count than actual, and the assembly guard `_results.map((r) => r!)` on line 237 may throw if a null slot is accessed before `_completedCount` catches up. More concretely: if `_completedCount` reflects an old value and the `Future.wait` resolves, `_assembleResult` is called with potentially null entries, causing a non-nullable cast crash.

**Fix:** Use `_updateChunkState` (which already notifies listeners) for the success case too, and keep the counter update and `_results` write together atomically in one synchronous block:

```dart
// In _processChunk, success branch — no await between these lines:
_results[index] = result;
_completedCount++;
_chunkStates[index] = ChunkDone(index, text: result.text);
_set(ChunkedProcessing(
  chunks: List.unmodifiable(_chunkStates),
  completedCount: _completedCount,
  totalCount: _chunkStates.length,
));
return;
```

The current code already does this (lines 273-281) without an intervening `await`, so the increment is safe in Dart. However, the null-safety issue in `_assembleResult` (line 237: `r!`) is still real: if any chunk future throws after being partially written, `_results[index]` remains null and the `!` force-unwrap will crash. `Future.wait` propagates the *first* error but still awaits all futures, so a failure in one chunk does not prevent `_assembleResult` from running if the outer `try/catch` is wrong. In practice the outer `catch` on line 220 intercepts all errors before `_assembleResult`, but only if `Future.wait` itself throws — if a chunk future completes normally after a sibling throws, `_results` can contain nulls when the error path is not taken. The safest fix is to guard the assembly:

```dart
final assembled = _assembleResult(
  _results.map((r) => r ?? TranscriptionResult.empty()).toList(),
  chunkDuration,
);
```

Or assert completeness before assembling:

```dart
assert(_results.every((r) => r != null), 'Unexpected null result after Future.wait');
```

---

### CR-03: Missing `await` on `_chunkedController!.start()` swallows all uncaught errors

**File:** `lib/ui/screens/processing_screen.dart:169`

**Issue:** `_chunkedController!.start(normalizedAudioFile)` is called without `await`. The method is `async` and returns a `Future<void>`. Any exception thrown inside `start()` that is not caught by the controller's own `try/catch` blocks (e.g., an `AssertionError`, an unhandled `Error` subclass, or a coding mistake in a future refactor) will become an unhandled `Future` rejection that is silently swallowed by the Dart runtime. This also means `_startProcessing`'s own `try/catch` (around the normalization, lines 137-148) cannot catch anything from the chunked controller.

Additionally, because the future is fire-and-forget, if the widget is disposed mid-processing, `_chunkedController!.start` will continue running and may call `notifyListeners()` on a disposed `ChangeNotifier`, which throws in debug mode.

**Fix:**

```dart
// In _startProcessing, chunked branch:
if (_isChunked) {
  _chunkedController = ChunkedTranscriptionController(
    pool: widget.groqKeyPool,
    apiService: GroqApiService(),
    chunkingService: AudioChunkingService(),
  );
  _chunkedController!.addListener(_onChunkedStateChange);
  // Await so unhandled errors propagate to this Future's error zone.
  await _chunkedController!.start(normalizedAudioFile);
} else {
  await _controller.start(normalizedAudioFile);
}
```

Note: `_controller.start()` on line 173 has the same problem — it is also called without `await`.

---

### CR-04: `KeyStatusTile` uses `DateTime.now()` instead of pool's `clock.now()`, causing visible time drift and breaking tests

**File:** `lib/ui/widgets/key_status_tile.dart:93`

**Issue:** The countdown remaining time is calculated as `s.blockedUntil.difference(DateTime.now())`. The `GroqKeyPool` records block expiry using `clock.now()` (from the `clock` package), which is injectable for tests. `KeyStatusTile` uses the real wall clock unconditionally. In production this is usually fine, but:

1. In widget tests (`api_keys_screen_status_test.dart`) the countdown is calculated against the real `DateTime.now()`, so the test passes only if it runs fast enough — it is a time-sensitive test that will flake under load or on slow CI.
2. More critically: `_isBlocked()` in the pool also uses `clock.now()` to decide when to auto-unblock a key and wake waiters. If the system clock and `clock.now()` diverge (e.g., in a test with `FakeClock`), the UI will show "Активен" while the pool still treats the key as blocked (or vice versa), causing confusing UI states.

**Fix:** Pass `clock` or a `DateTime Function()` into `KeyStatusTile`, or at minimum use `package:clock`'s `clock.now()` consistently:

```dart
// key_status_tile.dart, line 93
final remaining = s.blockedUntil.difference(clock.now());
```

Add `import 'package:clock/clock.dart';` at the top of the file.

---

## Warnings

### WR-01: `_onChunkedStateChange` calls `setState` twice — second call is a no-op but can crash post-navigation

**File:** `lib/ui/screens/processing_screen.dart:177-195`

**Issue:** On the `ChunkedSuccess` path, `setState(() {})` is called on line 182, then `Future.delayed(..., () { if (mounted) Navigator.pushReplacementNamed(...) })` is scheduled. After the `if (s is ChunkedSuccess)` block, `if (mounted) setState(() {})` on line 194 fires unconditionally on *every* state change, including `ChunkedSuccess`. During the 300 ms delay between the first `setState` and navigation, any additional `notifyListeners()` from the controller will trigger the second `setState` again, potentially after the route has started its replacement animation. While `mounted` guards prevent a crash, the double rebuild on every successful chunked completion is wasteful and the pattern is fragile.

**Fix:** Add `return` after handling `ChunkedSuccess` to avoid the unconditional second setState:

```dart
void _onChunkedStateChange() {
  final s = _chunkedController?.state;
  if (s is ChunkedSuccess) {
    _ticker?.cancel();
    if (mounted) {
      setState(() {});
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            AppConstants.routeResult,
            arguments: ResultArgs(file: _file!, result: s.result),
          );
        }
      });
    }
    return; // ← prevents falling through to the unconditional setState below
  }
  if (mounted) setState(() {});
}
```

---

### WR-02: `chunkDuration` variable is assigned and immediately overwritten — dead code and misleading

**File:** `lib/features/transcription/chunked_transcription_controller.dart:167-177`

**Issue:** `chunkDuration` is set to `kChunkDurationSeconds` on line 167, then inside the `if (metadata.durationSeconds > 0)` block on line 173 it is set to `kChunkDurationSeconds` again — the same constant. The metadata fetch is performed, the result parsed, but never actually used. The variable `metadata` is consumed only for its `durationSeconds > 0` check, which does nothing. This is dead code that adds confusion: a reader expects the chunk duration to depend on the file's actual duration, but it always equals the constant. If this is intentional (fixed chunk size), the metadata fetch and conditional block should be removed.

**Fix:** Remove the dead block:

```dart
// В start(): убрать весь try/catch с getMetadata — не используется
final double chunkDuration = kChunkDurationSeconds;
```

If future phases need adaptive chunk sizing, add a TODO comment instead of silent dead code.

---

### WR-03: `_processChunk` loop can exit via the `while` condition and throw the wrong exception type

**File:** `lib/features/transcription/chunked_transcription_controller.dart:255-302`

**Issue:** The retry loop exits when `attempt >= maxAttempts` inside the `NetworkException` handler (line 292-295) by rethrowing a new `NetworkException`. However, when `RateLimitException` is caught, `attempt` is incremented but the loop continues — no check is made for `attempt >= maxAttempts` in the rate-limit branch. If `maxAttempts` (10) `RateLimitException`s occur in sequence (all keys are exhausted repeatedly), the loop condition `attempt < maxAttempts` (line 255) will eventually become false, and execution falls through to line 301: `throw const NetworkException('Превышено максимальное число попыток')`. This is the correct exception type, but the message is misleading — it was rate-limited 10 times, not a network failure. More importantly, the `AllKeysBlockedException` from `acquireKey()` (after the 10-minute timeout) is not caught inside `_processChunk`; it propagates up to `Future.wait` which will surface it as a generic `catch (e)` resulting in a "Неизвестная ошибка" message.

**Fix:** Explicitly catch `AllKeysBlockedException` in `_processChunk`:

```dart
} on AllKeysBlockedException {
  rethrow; // Surface directly to Future.wait → ChunkedError with proper message
}
```

And/or add a rate-limit attempt cap:

```dart
} on RateLimitException catch (e) {
  attempt++;
  _pool.reportRateLimited(key, e.retryAfterSeconds);
  if (attempt >= maxAttempts) {
    throw const NetworkException('Превышено число попыток (rate limit)');
  }
  _updateChunkState(index, ChunkRetrying(index, attempt: attempt));
}
```

---

### WR-04: `ApiKeysScreen` does not validate raw key before adding to pool — pool and repository can diverge

**File:** `lib/ui/screens/api_keys_screen.dart:62-81`

**Issue:** `_onAddPressed` calls `_repository.addKey(rawKey)` first (line 69). If validation passes in the repository, `widget.pool.addKey(rawKey)` is called next (line 71). However, if `rawKey` is an empty string or whitespace, the repository may validate correctly (depending on its implementation, which is not in scope here), but `pool.addKey('')` would insert an empty key into the pool. An empty key would produce a `Bearer ` authorization header with no secret, which Groq would reject with a 401. The 401 triggers `AuthException` (non-retryable), blocking the entire transcription. More importantly the error will be confusing because the user believes they have valid keys.

Additionally, `_inputController.text` is read without `.trim()` — a user who accidentally adds trailing whitespace gets a key stored with spaces that will always fail authentication.

**Fix:**

```dart
final rawKey = _inputController.text.trim();
if (rawKey.isEmpty) {
  setState(() => _errorMessage = 'Ключ не может быть пустым');
  setState(() => _saving = false);
  return;
}
```

---

### WR-05: `ChunkRetrying` label hardcodes "/3" but `maxAttempts` is 10

**File:** `lib/features/transcription/chunk_state.dart:32` and `lib/ui/widgets/chunk_tile.dart:88`

**Issue:** `ChunkRetrying` displays `'Часть ${index + 1}: повтор $attempt/3...'` and `ChunkTile` renders `'Повтор $attempt/3'`. The constant max attempts in `_processChunk` is `10` (line 253 of `chunked_transcription_controller.dart`), not 3. The UI will show "Повтор 7/3" which is nonsensical to users and indicates a broken assumption in the design.

**Fix:** Either pass `maxAttempts` into `ChunkRetrying`, or change the hardcoded `/3` to reflect the actual cap. If 3 retries are the intended per-chunk NetworkException cap, change `maxAttempts` in the controller:

```dart
// chunk_state.dart
class ChunkRetrying extends ChunkState {
  final int attempt;
  final int maxAttempts;
  const ChunkRetrying(int index, {required this.attempt, this.maxAttempts = 10})
      : super(index: index, label: 'Часть ${index + 1}: повтор $attempt/$maxAttempts...');
}
```

---

### WR-06: `transcribe()` in `GroqApiService` silently ignores 429 responses — single-file mode has no rate-limit handling

**File:** `lib/features/transcription/groq_api_service.dart:204-208`

**Issue:** In `transcribe()` (the single-shot, non-chunked path), the HTTP 429 response falls through to the generic catch on line 208: `throw const NetworkException(_networkErrorMessage)`. Unlike `transcribeChunk()`, the 429 is not converted to a `RateLimitException`. This means `TranscriptionController.start()` never receives a `RateLimitException` and cannot call `_pool.reportRateLimited()` — the key is not blacklisted in the pool, so subsequent retries will hit the same rate-limited key again and again, wasting attempts and potentially surfacing a misleading "network error" to the user.

**Fix:** Apply the same 429/503 handling as in `transcribeChunk()`:

```dart
// In transcribe(), after the 401 check:
if (response.statusCode == 429 || response.statusCode == 503) {
  final retryAfterSeconds = parseRetryAfterFromHeaders(response.headers);
  throw RateLimitException(
    response.statusCode == 429
        ? 'Превышен лимит запросов Groq'
        : 'Сервис временно недоступен (503)',
    retryAfterSeconds: retryAfterSeconds,
  );
}
```

---

## Info

### IN-01: `all_keys_blocked_exception.dart` re-export file adds an unnecessary indirection

**File:** `lib/core/error/all_keys_blocked_exception.dart:1-3`

**Issue:** This file exists solely to re-export `AllKeysBlockedException` from `app_exception.dart`. The comment says "sealed class ограничивает наследование тем же файлом" — but `AllKeysBlockedException` is already a subclass of `AppException` in `app_exception.dart` and Dart sealed classes are restricted to the *library* (file), not the package. Having a separate re-export file creates two import paths for the same symbol, which can cause confusion and duplicate symbol warnings in IDEs.

**Fix:** Delete `all_keys_blocked_exception.dart` and update all importers to use `app_exception.dart` directly. There are no external consumers of this re-export visible in the reviewed files.

---

### IN-02: Misleading comment in test file — expected value contradicts the comment

**File:** `test/unit/groq_api_service_rate_limit_test.dart:42-50`

**Issue:** The test for `'2m59.56s'` has a comment saying "Но тест ожидает 179" and then immediately corrects itself to say the expected value is 180. The commented-out expectation (`expect(result, 179)`) was never removed. The comment creates confusion for future readers and suggests the developer was uncertain about the correct value.

**Fix:** Remove the dead comment lines 47-49, leaving only the authoritative assertion `expect(result, 180)`.

---

### IN-03: Test `'таймер уменьшает отсчёт через 1 секунду'` does not actually verify decrease

**File:** `test/widget/api_keys_screen_status_test.dart:43-63`

**Issue:** After pumping 1 second (`await tester.pump(const Duration(seconds: 1))`), the test asserts `find.textContaining('До 00:01:')` — the *same* prefix as the initial state. The countdown started at ~90 s ("До 00:01:30") and after 1 s should read "До 00:01:29". Both match `'До 00:01:'`, so the assertion does not distinguish whether the timer actually decremented or remained frozen. The test always passes regardless of whether `setState` was called.

**Fix:** Assert the specific pre- and post-tick values:

```dart
// Before tick
expect(find.text('До 00:01:30'), findsOneWidget);

await tester.pump(const Duration(seconds: 1));

// After 1 s tick
expect(find.text('До 00:01:29'), findsOneWidget);
```

Note: This also exposes that the test uses `DateTime.now()` directly (CR-04), so precise assertions will be timing-sensitive unless `clock` is injected.

---

_Reviewed: 2026-05-18T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
