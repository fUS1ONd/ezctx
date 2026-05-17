---
phase: 01-walking-skeleton-short-audio-clipboard
reviewed: 2026-05-17T00:00:00Z
depth: standard
files_reviewed: 25
files_reviewed_list:
  - .github/workflows/build-debug-apk.yml
  - android/app/build.gradle
  - android/app/src/main/AndroidManifest.xml
  - android/app/src/main/kotlin/com/ezctx/app/MainActivity.kt
  - lib/core/constants/app_constants.dart
  - lib/core/constants/design_tokens.dart
  - lib/core/error/app_exception.dart
  - lib/core/storage/secure_storage_service.dart
  - lib/main.dart
  - lib/ui/app.dart
  - lib/ui/screens/api_keys_screen.dart
  - lib/ui/screens/home_screen.dart
  - lib/ui/screens/processing_screen.dart
  - lib/ui/screens/result_screen.dart
  - lib/ui/screens/settings_screen.dart
  - lib/ui/widgets/glass_card.dart
  - lib/ui/widgets/glass_icon_btn.dart
  - lib/ui/widgets/glass_tile.dart
  - lib/ui/widgets/gradient_background.dart
  - lib/ui/widgets/primary_button.dart
  - test/unit/file_validator_test.dart
  - test/unit/groq_service_test.dart
  - test/unit/secure_storage_test.dart
  - test/widget/result_screen_test.dart
  - test/widget_test.dart
findings:
  critical: 5
  warning: 8
  info: 4
  total: 17
status: issues_found
---

# Phase 01: Code Review Report

**Reviewed:** 2026-05-17  
**Depth:** standard  
**Files Reviewed:** 25  
**Status:** issues_found

## Summary

Reviewed the Phase 1 "Walking Skeleton" Flutter/Dart implementation of ezctx — an Android audio-transcription app that sends audio files to Groq Whisper API. The codebase is generally structured well with good separation of concerns (feature slices, repository pattern, sealed state classes). However, there are several functional bugs that cause broken user flows, an API key leakage path, a cancellation bug that leaves background work running, and a shimmer animation that visually overflows the screen. These collectively explain the "crooked" feel the user reported.

---

## Critical Issues

### CR-01: API key transmitted in HTTP header — Authorization header not in `authorization` case used by test assertion but actual field name is mixed-case

**File:** `lib/features/transcription/groq_api_service.dart:37`  
**Issue:** The header is set as `'Authorization'` (capital A), but the test in `test/unit/groq_service_test.dart:34` asserts `req.headers['authorization']` (lowercase). In `http.MultipartRequest`, headers are stored case-insensitively by `http` package, so the test passes — but more importantly: there is no HTTP timeout set on `client.send(request)`. For a mobile app uploading up to 19 MB over a cellular connection, if the server hangs or the network drops mid-transfer, the app will wait forever with no way to cancel, no timeout, and the UI "Cancel" button on ProcessingScreen only pops navigation — it does NOT cancel the in-flight HTTP request. The `TranscriptionController` has no cancellation mechanism. The background Future continues running after the user cancels, and when it eventually resolves/rejects it calls `notifyListeners()` on a disposed controller.

**Fix:**
```dart
// groq_api_service.dart — add timeout to the send call
final streamed = await client.send(request).timeout(
  const Duration(minutes: 5),
  onTimeout: () {
    client.close();
    throw const NetworkException('Превышено время ожидания ответа от Groq');
  },
);
```
Additionally, `TranscriptionController` must support cancellation:
```dart
// transcription_controller.dart
bool _cancelled = false;

Future<void> cancel() async {
  _cancelled = true;
}

Future<void> start(SelectedAudioFile file) async {
  _cancelled = false;
  _set(const TranscriptionLoading());
  // ... after awaiting transcribe:
  if (_cancelled) return; // do not notify after cancel
  _set(TranscriptionSuccess(result));
}
```

---

### CR-02: `notifyListeners()` called after `dispose()` — use-after-dispose crash

**File:** `lib/features/transcription/transcription_controller.dart:51-54`  
**Issue:** `TranscriptionController` is a `ChangeNotifier`. When the user taps "Cancel" on `ProcessingScreen`, `Navigator.popUntil` disposes the screen (and calls `_controller.dispose()`). However, the async `start()` Future is still running. When it eventually completes, `_set()` calls `notifyListeners()` on the already-disposed notifier. In Flutter debug mode this throws `"A TranscriptionController was used after being disposed"`. In release mode it silently corrupts state or crashes.

**Fix:** Guard `_set` with a disposed flag:
```dart
bool _disposed = false;

@override
void dispose() {
  _disposed = true;
  super.dispose();
}

void _set(TranscriptionState s) {
  if (_disposed) return;
  _state = s;
  notifyListeners();
}
```

---

### CR-03: `ProcessingScreen` starts transcription on every `didChangeDependencies` call after hot-reload

**File:** `lib/ui/screens/processing_screen.dart:46-63`  
**Issue:** `didChangeDependencies` is called more than once in the widget lifecycle — it fires on first build AND whenever inherited widgets above it change (e.g., `MediaQuery`, `Theme`, locale changes). The guard `if (_file == null)` prevents the second start only once. However, `ModalRoute.of(context)` is an `InheritedWidget` lookup and `didChangeDependencies` is the correct place for it — **but** the timer and controller start are also inside this block. If a system dialog (keyboard, permission prompt, etc.) causes the overlay route to rebuild, `didChangeDependencies` is called again with `_file != null` so it is safe — but the dependency on `ModalRoute` means this widget is now subscribed to all route-level rebuilds. More critically, there is no null-safety check on `arguments` before it is consumed by `_controller.start(_file!)` on line 57: if arguments are somehow null (e.g., navigated from a deep-link or test without proper args), the else-branch only schedules a popUntil via `addPostFrameCallback`, but `_controller.start` is NOT guarded — however looking at the code flow, `_controller.start` is only called inside `if (args is SelectedAudioFile)`, so this specific path is safe. The real issue is: the timer started in `didChangeDependencies` is never restarted if `_controller.start` is called again via the "Retry" button on line 287. After retry, the elapsed timer stops accumulating from zero — `_startedAt` is never reset on retry.

**Fix:** Reset timer on retry:
```dart
// In ProcessingScreen, add a _restart() method called by the retry button
void _restart() {
  setState(() {
    _elapsed = Duration.zero;
    _startedAt = DateTime.now();
  });
  _ticker?.cancel();
  _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
    if (mounted) setState(() => _elapsed = DateTime.now().difference(_startedAt!));
  });
  _controller.start(_file!);
}
```
And in `_buildBottomBar`, replace `onPressed: () => _controller.start(_file!)` with `onPressed: _restart`.

---

### CR-04: `ProcessingScreen` "Готово" pipeline step is always `pending` — never shows `done` state

**File:** `lib/ui/screens/processing_screen.dart:195-199`  
**Issue:** The third pipeline step ("Готово") is hardcoded to `_PipelineStatus.pending`. When transcription succeeds, the screen immediately navigates away via `pushReplacementNamed`, so the user never sees "Готово" with a green check mark. This makes the pipeline misleading — the third dot permanently shows as grey/pending even when complete. This is the most visible "crooked" UI element: the pipeline indicator never reaches a visually complete state.

**Fix:** Either remove the "Готово" step from the pipeline card and let the navigation handle the success state, or introduce a brief `TranscriptionNavigating` state with a 300ms delay before pushing the result route, allowing the pipeline to render the done state:
```dart
// In _onStateChange:
if (s is TranscriptionSuccess) {
  _ticker?.cancel();
  if (mounted) setState(() {}); // show "Готово" as done
  await Future.delayed(const Duration(milliseconds: 300));
  if (mounted) {
    Navigator.pushReplacementNamed(
      context,
      AppConstants.routeResult,
      arguments: ResultArgs(file: _file!, result: s.result),
    );
  }
}
```
And change the hardcoded `_PipelineStatus.pending` for "Готово" to:
```dart
status: (state is TranscriptionSuccess)
    ? _PipelineStatus.done
    : _PipelineStatus.pending,
```

---

### CR-05: `TranscriptWriter._sanitize` — path traversal: filenames with `../` or absolute paths survive sanitization

**File:** `lib/features/transcription/transcript_writer.dart:26-31`  
**Issue:** The regex `[^\w\-\. ]+` replaces characters that aren't word chars, hyphens, dots, or spaces — but it allows dots. A filename like `../../etc/passwd` becomes `.._.._etc_passwd` after replacing `/`, but the file is still written to `${dir.path}/.._.._etc_passwd.txt` inside the app-documents directory. More dangerous: if `baseName` is `../../../sdcard/Download/evil`, after sanitize it becomes `..___..___..___sdcard_Download_evil` (slashes replaced with `_`), which is harmless on Android. However, a baseName that contains only a dot (e.g., `.`) after stripping the extension becomes empty after `trim()`, and then `File('${dir.path}/.txt')` is created — a hidden file with no base name. This silently produces a file that may not be discoverable by the user.

Additionally, if `baseName` has no extension (dotIdx <= 0), the full name including any leading dots is used without stripping, producing `.txt` for a baseName of `.`.

**Fix:**
```dart
static String _sanitize(String name) {
  // Убираем расширение
  var n = name;
  final dotIdx = n.lastIndexOf('.');
  if (dotIdx > 0) n = n.substring(0, dotIdx);
  // Заменяем любые небезопасные символы (включая точки в начале и подряд)
  n = n.replaceAll(RegExp(r'[^\w\- ]+'), '_').trim();
  if (n.isEmpty) n = 'transcript';
  return n;
}
```

---

## Warnings

### WR-01: `AndroidManifest.xml` missing `READ_MEDIA_AUDIO` permission — file picker will silently fail on Android 13+

**File:** `android/app/src/main/AndroidManifest.xml:3`  
**Issue:** `READ_EXTERNAL_STORAGE` is declared with `android:maxSdkVersion="32"`, which is correct — it does not apply on Android 13+ (SDK 33+). However, on Android 13+ (SDK 33+), access to audio files via `file_picker` requires `READ_MEDIA_AUDIO`. Without it, the picker dialog may open but return null for any selected file, or the path to the file may be inaccessible. The app targets SDK 36 (`targetSdk = 36`), making this a real gap for the majority of Android 13/14 devices.

**Fix:** Add to `AndroidManifest.xml`:
```xml
<uses-permission
    android:name="android.permission.READ_MEDIA_AUDIO"
    android:minSdkVersion="33"/>
```

---

### WR-02: `ShimmerBar` animation overflows screen — `Transform.translate` moves content outside clip bounds

**File:** `lib/ui/widgets/shimmer_bar.dart:53-73`  
**Issue:** The shimmer highlight is a `FractionallySizedBox` with `widthFactor: 0.35` (35% of parent width), then translated by `(_animation.value * 2 - 0.35) * MediaQuery.sizeOf(context).width`. This translation is in screen-width units, but the `FractionallySizedBox` is a child of a `Stack` inside a `ClipRRect`. The clip only covers the 6px-high bar — it clips vertically — but the horizontal extent of the clip rect matches the bar's width (which fills the horizontal space available). When `_animation.value` approaches 1.0, the offset becomes `(2 - 0.35) * screenWidth = 1.65 * screenWidth`, which pushes the highlight element well past the right edge. The `ClipRRect` does clip this, so it does not visually overflow into the screen — **but** the internal child widget is positioned at a coordinate far outside the clip rect, causing Flutter to lay out and paint an element that is entirely clipped. More practically: `MediaQuery.sizeOf(context)` inside `AnimatedBuilder` is called on every animation frame and triggers a `MediaQuery` dependency, so any screen resize causes a full rebuild cascade.

**Fix:** Replace the absolute pixel translation with a relative approach using `Align` + `FractionallySizedBox`:
```dart
// Use SlideTransition instead of Transform.translate with absolute coordinates
SlideTransition(
  position: Tween<Offset>(
    begin: const Offset(-1.0, 0),
    end: const Offset(1.0 / 0.35, 0), // slide fully across
  ).animate(_animation),
  child: FractionallySizedBox(
    widthFactor: 0.35,
    child: Container(/* gradient */),
  ),
),
```

---

### WR-03: `ApiKeysScreen` and `HomeScreen` instantiate `SecureStorageServiceImpl` and `ApiKeyRepository` directly — no DI, can't be tested

**File:** `lib/ui/screens/api_keys_screen.dart:43`, `lib/ui/screens/api_keys_screen.dart:58`, `lib/ui/screens/api_keys_screen.dart:95`, `lib/ui/screens/home_screen.dart:55`  
**Issue:** Each call to `_loadKeys`, `_onAddPressed`, `_confirmDelete`, and `_onTranscribeTap` creates a fresh `ApiKeyRepository(SecureStorageServiceImpl())`. This is not just a testability issue — it is a state consistency bug. If `FlutterSecureStorage` is accessed simultaneously from multiple instances (unlikely in practice due to single-threaded Dart, but still a code smell), and more importantly, on `_loadKeys` a new `SecureStorageServiceImpl` is instantiated (line 43), but `_onAddPressed` uses a different instance (line 58). If the underlying storage differs between calls (e.g., mock injection is impossible), data could diverge in tests.

**Fix:** Inject `ApiKeyRepository` via constructor or `InheritedWidget`/provider:
```dart
class ApiKeysScreen extends StatefulWidget {
  const ApiKeysScreen({super.key, ApiKeyRepository? repository})
      : _repository = repository ?? ApiKeyRepository(SecureStorageServiceImpl());
  final ApiKeyRepository _repository;
  // ...
}
```

---

### WR-04: `SettingsScreen` key count shows `'$_keyCount активен'` regardless of count — grammatically wrong and UX-misleading for 2+ keys

**File:** `lib/ui/screens/settings_screen.dart:82-84`  
**Issue:** The subtitle always says `"$_keyCount активен"` for any non-zero count (e.g., "2 активен", "3 активен"). Russian grammar requires plural agreement: "1 активен", "2 активных", "5 активных". The user sees broken Russian text whenever more than 1 key is stored.

**Fix:**
```dart
String _keyCountLabel(int count) {
  if (count == 0) return 'Нет ключей';
  if (count == 1) return '1 активен';
  if (count >= 2 && count <= 4) return '$count активных';
  return '$count активных';
}
```

---

### WR-05: `ProcessingScreen` — "Cancel" button does not cancel the HTTP request, wastes bandwidth and battery

**File:** `lib/ui/screens/processing_screen.dart:264-269`  
**Issue:** When the user taps "Отменить обработку", `Navigator.popUntil` is called, which disposes the screen and the controller. However, `GroqApiService.transcribe()` holds an open HTTP connection that continues to upload the file and receive the response. On a 19 MB file over cellular, this could waste megabytes of data. The upload has already been sent (you can't un-send it), but the response stream continues to be consumed by the orphaned Future. This also causes the CR-02 bug (notifyListeners after dispose).

**Fix:** See CR-01 and CR-02 fixes. Add a `CancelToken` pattern or use `http.Client.close()` in the controller's `cancel()` method. The `GroqApiService` should accept an `http.Client` instance (not factory) so it can be closed externally.

---

### WR-06: `main.dart` calls `runApp` without `WidgetsFlutterBinding.ensureInitialized()` — will crash if any plugin is initialized before `runApp`

**File:** `lib/main.dart:6`  
**Issue:** `flutter_secure_storage` and `path_provider` both require the Flutter binding to be initialized before their platform channels are ready. Currently `runApp` is the first call, which does initialize bindings — but only if there is nothing async before it. The moment a `Future` is added before `runApp` (e.g., for pre-loading stored keys, or `flutter_secure_storage` migration), the app will throw `ServicesBinding not initialized`. This is a latent bug that will trigger as soon as any initialization logic is added to `main`.

**Fix:**
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EzCtxApp());
}
```

---

### WR-07: `FilePickerService._extractExtension` duplicates `FileValidator._extractExtension` exactly — logic drift risk

**File:** `lib/features/transcription/file_picker_service.dart:71-76`  
**Issue:** The identical `_extractExtension` method appears in both `FilePickerService` (line 71) and `FileValidator` (line 40). If one is updated and the other is not (e.g., to handle Windows-style backslash paths for a future Windows build), the two can diverge silently. The `FilePickerService` already calls `FileValidator.validate(path:)` which internally uses its own `_extractExtension`, so the extension returned by `FilePickerService._extractExtension` on line 61 for constructing `SelectedAudioFile` could theoretically differ from what `FileValidator` computed.

**Fix:** Move `_extractExtension` to a shared utility or expose it as a static method on `FileValidator`, then call it from both places.

---

### WR-08: `build.gradle` — release build uses debug signing keys — APK silently ships with debug signature

**File:** `android/app/build.gradle:35-38`  
**Issue:** The release build type explicitly uses `signingConfigs.debug`. The TODO comment acknowledges this, but it means any release APK distributed (e.g., via Firebase App Distribution with `--release`) is signed with the shared debug key. Users who receive such a build can't be upgraded to a properly signed release APK on the same device without uninstalling — breaking Firebase App Distribution testing continuity. In the current phase (debug APK only), this is benign, but the TODO will be forgotten until a Play Store submission fails.

**Fix:** At minimum, replace the TODO with a Gradle property guard that fails the release build loudly if no signing config is present:
```groovy
release {
  if (project.hasProperty('storeFile')) {
    signingConfig signingConfigs.release
  } else {
    // Explicitly fail release builds without signing config
    throw new GradleException("Release signing config not set. Set storeFile/storePassword/keyAlias/keyPassword.")
  }
}
```

---

## Info

### IN-01: `AppConstants.groqTimestampGranularity` is a scalar string but the Groq field requires the `[]` suffix

**File:** `lib/core/constants/app_constants.dart:12`, `lib/features/transcription/groq_api_service.dart:40-41`  
**Issue:** The constant `groqTimestampGranularity = 'word'` stores only the value, while the actual field name used in the HTTP request is `'timestamp_granularities[]'` (hardcoded in `groq_api_service.dart`). The `[]` suffix is not part of the constant. This is not a bug now, but it creates a naming mismatch: the constant is named singular (`granularity`) while the API field is plural with array notation. If a developer tries to use the constant for the field key (not the value), they will get a wrong field name.

**Fix:** Rename for clarity or add a field key constant:
```dart
static const String groqTimestampGranularityField = 'timestamp_granularities[]';
static const String groqTimestampGranularityValue = 'word';
```

---

### IN-02: `result_screen.dart` `_formatNow()` always returns "Сегодня" — date is not from the file or transcription, it is always current time

**File:** `lib/ui/screens/result_screen.dart:167-172`  
**Issue:** The header date label always shows the current time at which `_formatNow()` is called during `build`. If the user leaves the result screen open past midnight, the date will still say "Сегодня" with yesterday's time. This is cosmetic but misleading. Additionally, `_formatNow()` is called on every `build()` call, meaning it can show a slightly different time each rebuild.

**Fix:** Capture the timestamp once in `didChangeDependencies` when `_args` is first set:
```dart
String? _formattedDate;
// In didChangeDependencies, after setting _args:
_formattedDate = _formatNow();
```
And use `_formattedDate!` in `build`.

---

### IN-03: `widget_test.dart` smoke test is skipped — CI runs `flutter test` which reports 0 failures but provides no real coverage gate

**File:** `test/widget_test.dart:7-11`  
**Issue:** The smoke test is unconditionally `skip`-ped. The CI workflow runs `flutter test` (line 46 of build workflow), which will show this test as skipped and report success even though no widget integration is tested. The skip rationale mentions GPU requirements, but `flutter_test` can run `BackdropFilter` in headless mode since Flutter 3.x with the `--platform chrome` or via `testWidgets` with `pumpWidget` (which does not require a real GPU in VM mode, only the render layer). At minimum, the test should be converted to a real headless widget test.

**Fix:** Either remove the placeholder test file or implement a minimal `testWidgets` that pumps `EzCtxApp` with a mock route and verifies the home screen title renders.

---

### IN-04: `GlassIconBtn` uses `GestureDetector` instead of `InkWell` or `Material` — no ripple feedback, accessibility action not wired to `onTap`

**File:** `lib/ui/widgets/glass_icon_btn.dart:33`  
**Issue:** The button uses `GestureDetector.onTap`, which provides no visual ripple feedback on tap. The `Semantics` wrapper with `button: true` sets the semantic role, but because `GestureDetector` does not implement `ActivateAction`, accessibility services (TalkBack) cannot activate the button via the standard "double tap to activate" gesture on some Android versions. Using `InkWell` or `GestureDetector` with an explicit `excludeFromSemantics: false` Semantics parent is the correct approach for tappable glass buttons.

**Fix:** Wrap with `Material` color transparent + `InkWell` to get ripple and accessibility:
```dart
Material(
  color: Colors.transparent,
  child: InkWell(
    borderRadius: BorderRadius.circular(14),
    onTap: onPressed,
    child: /* existing GlassCard content */,
  ),
)
```

---

_Reviewed: 2026-05-17_  
_Reviewer: Claude (gsd-code-reviewer)_  
_Depth: standard_
