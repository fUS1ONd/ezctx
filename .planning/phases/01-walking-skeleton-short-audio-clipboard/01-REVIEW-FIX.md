---
phase: 01-walking-skeleton-short-audio-clipboard
fixed_at: 2026-05-17T00:00:00Z
review_path: .planning/phases/01-walking-skeleton-short-audio-clipboard/01-REVIEW.md
iteration: 1
findings_in_scope: 10
fixed: 10
skipped: 0
status: all_fixed
---

# Phase 01: Code Review Fix Report

**Fixed at:** 2026-05-17  
**Source review:** `.planning/phases/01-walking-skeleton-short-audio-clipboard/01-REVIEW.md`  
**Iteration:** 1

**Summary:**
- Findings in scope: 10 (5 Critical + 5 Warning)
- Fixed: 10
- Skipped: 0

---

## Fixed Issues

### CR-01: HTTP timeout на запрос к Groq

**Files modified:** `lib/features/transcription/groq_api_service.dart`  
**Commit:** fa82ac2  
**Applied fix:** Добавлен `.timeout(const Duration(minutes: 5))` с `onTimeout`-колбеком, который закрывает клиент и бросает `NetworkException`. `TimeoutException` уже перехватывался в `catch`-блоке, поэтому дополнительных изменений не потребовалось.

---

### CR-02: notifyListeners() после dispose() — crash при отмене

**Files modified:** `lib/features/transcription/transcription_controller.dart`  
**Commit:** 2427763  
**Applied fix:** Добавлен флаг `_disposed = false`, переопределён `dispose()` (устанавливает `_disposed = true`), в `_set()` добавлена ранняя проверка `if (_disposed) return`.

---

### CR-03: Таймер не сбрасывается при «Повторить»

**Files modified:** `lib/ui/screens/processing_screen.dart`  
**Commit:** 4b24dce  
**Applied fix:** Добавлен метод `_restart()`, который отменяет текущий тикер, сбрасывает `_elapsed` и `_startedAt` в `setState`, создаёт новый `Timer.periodic` и вызывает `_controller.start(_file!)`. Кнопка «Повторить» теперь вызывает `_restart` вместо прямого вызова `_controller.start`.

---

### CR-04: Шаг «Готово» всегда отображается как pending

**Files modified:** `lib/ui/screens/processing_screen.dart`  
**Commit:** 4b24dce (одним коммитом с CR-03)  
**Applied fix:** Статус третьего шага pipeline теперь `state is TranscriptionSuccess ? _PipelineStatus.done : _PipelineStatus.pending`. В `_onStateChange` добавлена задержка 300 мс перед переходом на экран результата — за это время пользователь видит зелёную галочку «Готово».

---

### CR-05: Пустой baseName после sanitize() создаёт скрытый файл

**Files modified:** `lib/features/transcription/transcript_writer.dart`  
**Commit:** b752539  
**Applied fix:** Изменён regex с `[^\w\-\. ]+` на `[^\w\- ]+` (исключены точки, чтобы они не могли создать скрытый файл вида `.txt`). Добавлена проверка `if (n.isEmpty) n = 'transcript'` после trim().

---

### WR-01: Отсутствует READ_MEDIA_AUDIO для Android 13+

**Files modified:** `android/app/src/main/AndroidManifest.xml`  
**Commit:** c206bd4  
**Applied fix:** Добавлена строка `<uses-permission android:name="android.permission.READ_MEDIA_AUDIO" android:minSdkVersion="33"/>` сразу после `READ_EXTERNAL_STORAGE`.

---

### WR-04: Неправильное русское склонение числа ключей

**Files modified:** `lib/ui/screens/settings_screen.dart`  
**Commit:** 808fc6d  
**Applied fix:** Добавлен метод `_keyCountLabel(int count)` с корректными формами: `'Нет ключей'` / `'1 активен'` / `'$count активных'`. Subtitle теперь использует этот метод.

---

### WR-06: main() без WidgetsFlutterBinding.ensureInitialized()

**Files modified:** `lib/main.dart`  
**Commit:** 00e7cf0  
**Applied fix:** `main()` стал `async`, добавлен `WidgetsFlutterBinding.ensureInitialized()` перед `runApp`.

---

### WR-07: Дублирование _extractExtension в FileValidator и FilePickerService

**Files modified:** `lib/features/transcription/file_validator.dart`, `lib/features/transcription/file_picker_service.dart`  
**Commit:** 4eecb0c  
**Applied fix:** Метод переименован в `extractExtension` и сделан `static` в `FileValidator`. Внутренний вызов в `validate()` обновлён на `FileValidator.extractExtension(path)`. Из `FilePickerService` дублирующий метод удалён, вызов заменён на `FileValidator.extractExtension(path)`.

---

### WR-03: ApiKeyRepository пересоздаётся на каждый вызов метода

**Files modified:** `lib/ui/screens/api_keys_screen.dart`, `lib/ui/screens/home_screen.dart`  
**Commit:** 83fb89d  
**Applied fix:** В `_ApiKeysScreenState` и `_HomeScreenState` добавлено поле `final ApiKeyRepository _repository = ApiKeyRepository(SecureStorageServiceImpl())`, инициализируемое при создании экземпляра. Все методы используют `_repository` вместо создания нового инстанса.

---

## Skipped Issues

None — все 10 findings успешно исправлены.

---

## Test Results

**flutter test test/unit/ — все 49 тестов пройдены:**
- FileValidator: 19 тестов — ok
- GroqApiService: 8 тестов — ok
- SecureStorageService: 5 тестов — ok
- ApiKeyRepository: 9 тестов — ok
- TranscriptionController: 8 тестов — ok

**flutter analyze --no-fatal-infos — No issues found**

---

_Fixed: 2026-05-17_  
_Fixer: Claude (gsd-code-fixer)_  
_Iteration: 1_
