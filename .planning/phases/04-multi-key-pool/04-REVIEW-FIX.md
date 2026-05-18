---
phase: 04-multi-key-pool
fixed_at: 2026-05-18T00:00:00Z
review_path: .planning/phases/04-multi-key-pool/04-REVIEW.md
iteration: 1
findings_in_scope: 10
fixed: 10
skipped: 0
status: all_fixed
---

# Phase 04: Code Review Fix Report

**Fixed at:** 2026-05-18T00:00:00Z
**Source review:** `.planning/phases/04-multi-key-pool/04-REVIEW.md`
**Iteration:** 1

**Summary:**
- Findings in scope: 10
- Fixed: 10
- Skipped: 0

## Fixed Issues

### CR-01: Key pool wakeup distributes same key to multiple concurrent waiters

**Files modified:** `lib/features/transcription/groq_key_pool.dart`
**Commit:** e339275
**Applied fix:** Rewrote `_onWakeup()` to issue exactly one key to exactly one waiter per call, then return immediately. Removed the `while` loop that handed the same key to all waiters in a single microtask turn. If there are no alive keys, `_scheduleWakeup()` is called and method returns early. Each waiter that receives a key and needs another will call `acquireKey()` again, creating its own waiter and scheduling a new wakeup — preventing 429 storms.

---

### CR-02: `_results.map((r) => r!)` force-unwrap crash on null slots

**Files modified:** `lib/features/transcription/chunked_transcription_controller.dart`, `lib/features/transcription/transcription_result.dart`
**Commit:** 8946b9f
**Applied fix:** Added `TranscriptionResult.empty()` const constructor to `TranscriptionResult`. Replaced `_results.map((r) => r!).toList()` with `_results.map((r) => r ?? TranscriptionResult.empty()).toList()` — null slots are replaced with an empty result instead of throwing a non-nullable cast crash.

---

### CR-03: Missing `await` on `_chunkedController!.start()` swallows errors

**Files modified:** `lib/ui/screens/processing_screen.dart`
**Commit:** dd657d3
**Applied fix:** Added `await` to both `_chunkedController!.start(normalizedAudioFile)` and `_controller.start(normalizedAudioFile)` in `_startProcessing()`. Uncaught exceptions inside `start()` now propagate to `_startProcessing`'s caller zone rather than being silently dropped as unhandled Future rejections.

---

### CR-04: `KeyStatusTile` uses `DateTime.now()` instead of `clock.now()`

**Files modified:** `lib/ui/widgets/key_status_tile.dart`
**Commit:** 29b2de1
**Applied fix:** Added `import 'package:clock/clock.dart'` and replaced `s.blockedUntil.difference(DateTime.now())` with `s.blockedUntil.difference(clock.now())`. UI countdown now uses the same injectable clock as `GroqKeyPool`, so widget tests using `FakeClock` will not flake due to wall-clock drift.

---

### WR-01: `_onChunkedStateChange` calls `setState` twice on `ChunkedSuccess`

**Files modified:** `lib/ui/screens/processing_screen.dart`
**Commit:** 8a7e4e4
**Applied fix:** Added `return;` after the `ChunkedSuccess` handling block so the unconditional `if (mounted) setState(() {})` at the end of the method is not reached on the success path.

---

### WR-02: Dead metadata fetch block in `start()`

**Files modified:** `lib/features/transcription/chunked_transcription_controller.dart`
**Commit:** 4d26a8c
**Applied fix:** Removed the entire `try/catch` block calling `_chunkingService.getMetadata()` — the variable `chunkDuration` was unconditionally assigned `kChunkDurationSeconds` both before and inside the block. Replaced with a single `const double chunkDuration = kChunkDurationSeconds;` and a `TODO` comment for future adaptive sizing.

---

### WR-03: `AllKeysBlockedException` not caught in `_processChunk`

**Files modified:** `lib/features/transcription/chunked_transcription_controller.dart`
**Commit:** 9753f03
**Applied fix:** Added `on AllKeysBlockedException { rethrow; }` catch clause so the exception surfaces directly to `Future.wait` → outer `catch (e)` with the correct type and message instead of "Неизвестная ошибка". Also added a `attempt >= maxAttempts` check in the `RateLimitException` branch so the loop terminates with a descriptive `NetworkException('Превышено число попыток (rate limit)')` rather than falling through to the generic fallback.

---

### WR-04: API key not trimmed before adding

**Files modified:** `lib/ui/screens/api_keys_screen.dart`
**Commit:** ef3c77f
**Applied fix:** Changed `_inputController.text` to `_inputController.text.trim()`. Added an explicit empty-string guard before calling `_repository.addKey()` — shows `_errorMessage = 'Ключ не может быть пустым'` and returns early without calling the repository or pool.

---

### WR-05: `ChunkRetrying` label hardcodes "/3" but `maxAttempts` is 10

**Files modified:** `lib/features/transcription/chunk_state.dart`, `lib/ui/widgets/chunk_tile.dart`
**Commit:** 172a543
**Applied fix:** Added `maxAttempts` parameter to `ChunkRetrying` (default 10). Updated label string to `повтор $attempt/$maxAttempts...`. Updated `ChunkTile` switch to destructure `maxAttempts` and render `'Повтор $attempt/$maxAttempts'`.

---

### WR-06: `transcribe()` treats 429 as `NetworkException`, bypasses rate-limit pool reporting

**Files modified:** `lib/features/transcription/groq_api_service.dart`
**Commit:** 230f439
**Applied fix:** Added `if (response.statusCode == 429 || response.statusCode == 503)` block in `transcribe()` (identical to the existing block in `transcribeChunk()`). Now throws `RateLimitException` with the parsed `retryAfterSeconds`, allowing `TranscriptionController.start()` to call `pool.reportRateLimited()` and avoid hammering a rate-limited key.

---

## Skipped Issues

None — all 10 in-scope findings were successfully fixed.

---

_Fixed: 2026-05-18T00:00:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
