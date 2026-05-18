---
phase: 05-model-language-controls
reviewed: 2026-05-18T00:00:00Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - lib/features/transcription/transcription_options.dart
  - lib/features/settings/transcription_options_repository.dart
  - lib/core/constants/app_constants.dart
  - lib/features/transcription/groq_api_service.dart
  - lib/features/transcription/processing_args.dart
  - lib/features/transcription/transcription_controller.dart
  - lib/features/transcription/chunked_transcription_controller.dart
  - lib/ui/screens/home_screen.dart
  - lib/ui/screens/processing_screen.dart
findings:
  critical: 0
  warning: 4
  info: 3
  total: 7
status: issues_found
---

# Code Review — Phase 5

## CRITICAL

Критических багов не обнаружено.

---

## WARNING

### WR-01: `_onStateChange` вызывает `setState` дважды при успехе — двойной ребилд

**File:** `lib/ui/screens/processing_screen.dart:204-223`

**Issue:**
```dart
void _onStateChange() {
  final s = _controller.state;
  if (s is TranscriptionSuccess) {
    _ticker?.cancel();
    if (mounted) {
      setState(() {});          // первый setState
      Future.delayed(..., () {
        if (mounted) { Navigator.pushReplacementNamed(...); }
      });
    }
  }
  if (mounted) setState(() {}); // второй setState — всегда выполняется
}
```
Когда `state is TranscriptionSuccess`, оба блока `if` не взаимоисключающие: первый `setState` внутри `if (s is TranscriptionSuccess)` выполняется, а затем безусловный `if (mounted) setState(() {})` в конце выполняется снова. Итог: два перестроения дерева вместо одного при каждом успешном завершении.

**Fix:**
```dart
void _onStateChange() {
  if (!mounted) return;
  final s = _controller.state;
  if (s is TranscriptionSuccess) {
    _ticker?.cancel();
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
    return; // прерываем, чтобы не вызывать setState второй раз
  }
  setState(() {});
}
```

---

### WR-02: Повторный вызов `_startProcessing` при retry не сбрасывает `_isChunked` и `_chunkedController`

**File:** `lib/ui/screens/processing_screen.dart:226-238`

**Issue:**
```dart
void _restart() {
  _ticker?.cancel();
  setState(() {
    _elapsed = Duration.zero;
    _startedAt = DateTime.now();
    _normalizationError = null;
    _normalizedFile = null;
    // _isChunked НЕ сбрасывается
    // _chunkedController НЕ утилизируется и не пересоздаётся
  });
  ...
  _startProcessing();
}
```
Если пользователь нажимает «Повторить» после сбоя нормализации (когда `_isChunked = false` ещё, но `_normalizedFile = null`), то `build()` при следующем рендере проверяет `if (_isChunked && _chunkedController != null)` — здесь `_isChunked` из предыдущей успешной нормализации может остаться `true`, и экран покажет chunked UI пока нормализация ещё идёт. Кроме того, старый `_chunkedController` не утилизируется, его listener остаётся висеть.

**Fix:**
```dart
void _restart() {
  _ticker?.cancel();
  _chunkedController?.removeListener(_onChunkedStateChange);
  _chunkedController?.dispose();
  setState(() {
    _elapsed = Duration.zero;
    _startedAt = DateTime.now();
    _normalizationError = null;
    _normalizedFile = null;
    _isChunked = false;
    _chunkedController = null;
  });
  ...
  _startProcessing();
}
```

---

### WR-03: `TranscriptionOptionsRepository` использует `flutter_secure_storage` для нечувствительных данных — избыточно и может вызвать сбои на Android без Keystore

**File:** `lib/features/settings/transcription_options_repository.dart:10-13`

**Issue:**
`flutter_secure_storage` использует Android Keystore. Настройки модели/языка (`whisper-large-v3`, `ru`) не являются секретными данными. На некоторых Android-устройствах (особенно старых или с заблокированным Keystore) операции secure storage могут завершаться с исключением. Метод `load()` ловит все исключения и возвращает дефолты, что скрывает реальные проблемы. Кроме того, обращение к secure storage выполняется каждый раз при `initState`, хотя для несекретных данных `SharedPreferences` достаточно и значительно быстрее.

Это архитектурное решение, принятое намеренно (CLAUDE.md требует хранить ключи в `flutter_secure_storage`), но это правило касается API-ключей, не пользовательских настроек.

**Fix:**
Рассмотреть хранение `TranscriptionOptions` в `SharedPreferences` вместо `flutter_secure_storage`. Если принципиально оставить secure storage — задокументировать причину явно в комментарии к классу.

---

### WR-04: `kChunkDurationSeconds` и `kChunkThresholdSeconds` — одинаковые значения, семантика разная, легко перепутать

**File:** `lib/core/constants/app_constants.dart:33-37`

**Issue:**
```dart
static const int kChunkThresholdSeconds = 4500;   // порог для isChunked
static const double kChunkDurationSeconds = 4500.0; // длина одного чанка
```
Обе константы равны 4500 (75 минут). Это совпадение создаёт риск: если в будущей фазе нужно изменить только одну из них (например, порог — 60 мин, чанк — 20 мин), разработчик может изменить одну и не заметить вторую. В `chunked_transcription_controller.dart:172` `const double chunkDuration = kChunkDurationSeconds` — используется только одна константа, но семантическая путаница остаётся.

**Fix:**
Добавить комментарии с явным указанием, что совпадение значений намеренное, и описать, когда они могут расходиться:
```dart
/// Порог длительности файла для перехода в chunked-режим.
/// Намеренно равен [kChunkDurationSeconds] — чанкование включается
/// только когда файл длиннее одного чанка.
static const int kChunkThresholdSeconds = 4500;

/// Длительность одного чанка при нарезке (75 мин × 240 КБ/мин ≈ 17.6 МБ).
/// Если изменить без обновления [kChunkThresholdSeconds], возможны 1-чанковые
/// chunked-запуски.
static const double kChunkDurationSeconds = 4500.0;
```

---

## INFO

### IN-01: `groqDefaultModel` и `groqTurboModel` в `AppConstants` стали мёртвым кодом

**File:** `lib/core/constants/app_constants.dart:9-10`

**Issue:**
```dart
static const String groqDefaultModel = 'whisper-large-v3';
static const String groqTurboModel = 'whisper-large-v3-turbo';
```
После фазы 5 модели задаются через `WhisperModel.apiValue` в `TranscriptionOptions`. Строковые константы `groqDefaultModel` и `groqTurboModel` нигде не используются — они дублируют значения из `WhisperModel` enum и создают риск расхождения при будущих изменениях.

**Fix:** Удалить обе константы из `AppConstants`.

---

### IN-02: `_languageItems` в `HomeScreen` — статический список вместо вычисляемого из enum

**File:** `lib/ui/screens/home_screen.dart:296-341`

**Issue:**
Список `_languageItems` захардкожен вручную из 11 значений. При добавлении нового языка в `TranscriptionLanguage` enum нужно не забыть добавить элемент сюда — компилятор этого не проверит.

**Fix:**
```dart
static final _languageItems = TranscriptionLanguage.values
    .map((lang) => DropdownMenuItem(
          value: lang,
          child: Text(_languageLabel(lang)),
        ))
    .toList();

static String _languageLabel(TranscriptionLanguage lang) => switch (lang) {
  TranscriptionLanguage.auto => 'Авто',
  TranscriptionLanguage.ru   => 'Русский',
  TranscriptionLanguage.en   => 'English',
  TranscriptionLanguage.de   => 'Deutsch',
  TranscriptionLanguage.fr   => 'Français',
  TranscriptionLanguage.es   => 'Español',
  TranscriptionLanguage.uk   => 'Українська',
  TranscriptionLanguage.zh   => '中文',
  TranscriptionLanguage.ja   => '日本語',
  TranscriptionLanguage.ko   => '한국어',
  TranscriptionLanguage.ar   => 'العربية',
};
```
Теперь компилятор потребует exhaustive switch при добавлении новых значений в enum.

---

### IN-03: `transcribeChunk` жёстко задаёт `contentType: MediaType('audio', 'mpeg')` для любого чанка

**File:** `lib/features/transcription/groq_api_service.dart:121-124`

**Issue:**
```dart
contentType: MediaType('audio', 'mpeg'),
```
Чанки всегда являются MP3 (результат нормализации через ffmpeg), поэтому `audio/mpeg` корректен. Однако нигде это не задокументировано — будущий разработчик может не знать об этом контракте и передать чанки другого формата, получив ошибку Groq вместо явной ошибки приложения.

**Fix:** Добавить комментарий:
```dart
// Чанки всегда в формате MP3 (результат AudioNormalizationService).
// Если изменить формат нормализации — обновить contentType здесь.
contentType: MediaType('audio', 'mpeg'),
```

---

## VERDICT

**NEEDS_FIXES**

Два предупреждения (WR-01, WR-02) касаются корректности поведения UI при edge cases — двойной ребилд при успехе и неполный сброс состояния при retry. Они не ломают основной сценарий, но могут вызвать видимые глитчи или утечку слушателей при повторных попытках. Рекомендуется исправить перед релизом.

---

_Reviewed: 2026-05-18_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
