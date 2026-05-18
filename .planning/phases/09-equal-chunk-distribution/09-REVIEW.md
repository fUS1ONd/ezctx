---
phase: 09-equal-chunk-distribution
reviewed: 2026-05-18T00:00:00Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - lib/core/constants/app_constants.dart
  - lib/features/transcription/audio_chunking_service.dart
  - lib/features/transcription/chunked_transcription_controller.dart
  - test/features/transcription/audio_chunking_service_test.dart
  - test/features/transcription/chunked_transcription_controller_test.dart
  - test/features/transcription/integration_chunked_flow_test.dart
findings:
  critical: 1
  warning: 3
  info: 2
  total: 6
status: issues_found
verdict: FAIL
---

# Phase 09: Code Review Report

**Reviewed:** 2026-05-18
**Depth:** standard
**Files Reviewed:** 6
**Status:** issues_found
**Verdict:** FAIL (1 Critical, 3 Warning → порог FAIL: любой Critical)

## Summary

Реализован алгоритм равномерного распределения чанков: N = ceil(total / 4920), optimalDuration = total / N. Константа `kChunkDurationSeconds` удалена, порог поднят до 4920. Гард `totalDurationSeconds <= 0` присутствует. Механика retry и семафор унаследованы без изменений.

Найдена одна критическая уязвимость: path injection в ffmpeg-команде. Три предупреждения: семантически мёртвый `min()` вокруг `clamp`, несоответствие ожидаемого таймкода в интеграционном тесте (тест **упадёт**), и рассинхрон между `chunkDuration` в контроллере и реальным числом чанков от ffmpeg.

---

## Critical Issues

### CR-01: Инъекция пути в ffmpeg-команду (command injection)

**File:** `lib/features/transcription/audio_chunking_service.dart:102`

**Issue:** `filePath` и `tmpBase` интерполируются напрямую в строку команды ffmpeg:

```dart
final command =
    '-i "$filePath" -f segment -segment_time $optimalDuration'
    ' -c:a copy'
    ' "$tmpBase/chunk_%03d.mp3"';
```

Двойные кавычки вокруг пути не обеспечивают защиты: путь вида `/tmp/file" -vn -acodec aac /malicious` разрывает кавычки и вставляет произвольные ffmpeg-флаги. На Android файлы выбираются через SAF/picker и реальный путь может содержать спецсимволы. `tmpBase` строится из `DateTime.now().millisecondsSinceEpoch` и не содержит спецсимволов сам по себе, но если `outputDir` задан извне (параметр `outputDir`), то он тоже уязвим.

**Fix:** Использовать `FFmpegKit.executeWithArgumentsAsync` (или `executeAsync` с разбивкой на токены через `FFmpegKitConfig`), передавая аргументы списком вместо одной строки. Альтернатива — санитизировать путь: запретить символы `"`, `'`, `` ` ``, `\`, `$`, `!` перед включением в команду:

```dart
// Вариант 1: токенизированный вызов (рекомендуется)
final args = [
  '-i', filePath,
  '-f', 'segment',
  '-segment_time', '$optimalDuration',
  '-c:a', 'copy',
  '$tmpBase/chunk_%03d.mp3',
];
// FFmpegKit не имеет нативного List<String> API в flutter-обёртке,
// поэтому минимально:

// Вариант 2: санитизация пути
String _sanitizePath(String path) {
  const forbidden = ['"', "'", '`', r'\', r'$', '!'];
  for (final ch in forbidden) {
    if (path.contains(ch)) {
      throw InternalException('Недопустимые символы в пути: $path');
    }
  }
  return path;
}

final safePath = _sanitizePath(filePath);
final safeDir  = _sanitizePath(tmpBase);
final command  = '-i "$safePath" -f segment -segment_time $optimalDuration'
    ' -c:a copy "$safeDir/chunk_%03d.mp3"';
```

---

## Warnings

### WR-01: Интеграционный тест с неверным ожидаемым таймкодом — тест упадёт

**File:** `test/features/transcription/integration_chunked_flow_test.dart:337-338`

**Issue:** `_dummyFile.durationSeconds = 3000.0` (50 мин). В `start()` контроллер вычисляет:

```
chunkN = ceil(3000 / 4920) = 1
chunkDuration = 3000 / 1 = 3000.0 с
```

Мок возвращает **2** чанка. Для чанка с индексом 1 смещение = `1 * 3000 = 3000 с = [00:50:00]`.

Тест ожидает `[01:15:00]` (= 4500 с), что неверно. Тест **не пройдёт**.

```dart
// Строка 338 — неверное ожидание:
expect(result.text, contains('[01:15:00] Как дела'), ...);
// Реальный таймкод при durationSeconds=3000: [00:50:00]
```

**Fix:** Привести `durationSeconds` в `_dummyFile` к значению, при котором `ceil(total / 4920) = 2`, т.е. `total > 4920`:

```dart
// Вариант: 9000s (150 мин) → N=2, chunkDuration=4500 → chunk 1 offset=4500=[01:15:00]
final _dummyFile = NormalizedAudioFile(
  path: '/tmp/test_lecture.mp3',
  durationSeconds: 9000.0, // 150 мин → N=2, chunkDuration=4500s
);
```

Тогда ожидание `[01:15:00]` будет корректным.

### WR-02: chunkDuration в контроллере вычисляется независимо от реального числа чанков ffmpeg

**File:** `lib/features/transcription/chunked_transcription_controller.dart:183-185`

**Issue:**

```dart
final chunkN =
    (file.durationSeconds / AppConstants.kChunkThresholdSeconds).ceil();
final chunkDuration = file.durationSeconds / chunkN;
```

Это значение используется для смещения таймкодов: `absoluteStart = i * chunkDuration + seg.start`. Но реальное число чанков берётся из `chunkFiles.length` (строка 187). Если ffmpeg по каким-то причинам сгенерировал иное число чанков (граничные условия длительности, погрешность `-segment_time`), таймкоды для последних чанков будут рассчитаны неверно.

Например: файл 9840 с (= 2 * 4920). `ceil(9840/4920) = 2`, `chunkDuration = 4920`. Но ffmpeg при `-segment_time 4920` может создать 3 чанка из-за погрешности кодека — тогда третий чанк получит offset `2 * 4920 = 9840 с` вместо реального `~9840 с`, что совпадёт. Однако при `total = 4921`, `N = 2`, `chunkDuration = 2460.5`. Если ffmpeg создаёт 3 чанка (что случается при сегментации по ключевым кадрам), третий чанк получит offset `2 * 2460.5 = 4921 с` вместо реального `~4921 с` — здесь это также совпадёт. Ситуация усугубляется при аудио с переменным битрейтом.

**Более надёжный подход:** хранить `optimalDuration` как результат `split()` (вернуть пару `(List<File>, double)`), либо принять `chunkDuration = file.durationSeconds / chunkFiles.length` после получения реального числа файлов.

```dart
// После строки 187:
final n = chunkFiles.length;
// Использовать реальное n, а не теоретическое chunkN:
final chunkDuration = n > 0 ? file.durationSeconds / n : file.durationSeconds;
```

### WR-03: Семантически мёртвый min() вокруг clamp — маскирует намерение

**File:** `lib/features/transcription/chunked_transcription_controller.dart:199-202`

**Issue:**

```dart
final concurrency = min(
  _pool.aliveKeyCount.clamp(1, AppConstants.kMaxConcurrentChunks),
  AppConstants.kMaxConcurrentChunks,
);
```

`clamp(x, 1, kMaxConcurrentChunks)` уже гарантирует результат ≤ `kMaxConcurrentChunks`, поэтому внешний `min(..., kMaxConcurrentChunks)` никогда не меняет значение — это мёртвый код. Кроме того, `clamp(0, 1, ...)` даёт 1, что означает: когда все ключи заблокированы (`aliveKeyCount == 0`), семафор всё равно равен 1 и задачи продолжают выполняться. Это может быть намеренным (ждать разблокировки ключа), но без явного комментария непонятно.

**Fix:** Упростить и задокументировать намерение:

```dart
// Минимум 1 чтобы не блокировать семафор навсегда при временном rate-limit всех ключей.
final concurrency = _pool.aliveKeyCount.clamp(1, AppConstants.kMaxConcurrentChunks);
```

---

## Info

### IN-01: Дублирование кода мок-классов между тестовыми файлами

**File:** `test/features/transcription/chunked_transcription_controller_test.dart` и `test/features/transcription/integration_chunked_flow_test.dart`

**Issue:** Классы `_FakeChunkFile` (~175 строк) и `_MockGroqApiService` (~25 строк) продублированы verbatim в обоих тестовых файлах. При изменении интерфейса `File` или `GroqApiService` нужно обновлять в двух местах.

**Fix:** Вынести в общий файл `test/features/transcription/test_helpers.dart` и импортировать в оба теста.

### IN-02: Тест «4 чанка (часовое аудио)» не проверяет алгоритм, а только длину списка файлов

**File:** `test/features/transcription/audio_chunking_service_test.dart:108-121`

**Issue:** Тест создаёт 4 файла в директории вручную, но коментарий утверждает `N=ceil(19800/4920)=5`. Реальный алгоритм при 19800с создаст 5 чанков, а тест проверяет только число возвращённых файлов (4 — столько создано вручную). Таким образом, тест не верифицирует алгоритм разбивки, а только то, что `listSync()` работает. Кроме того, комментарий противоречит ожидаемому `length == 4`.

**Fix:** Либо исправить комментарий, либо добавить тест, который захватывает команду ffmpeg (как тест на строке 135) и проверяет `-segment_time 3960.0` (= 19800/5).

---

_Reviewed: 2026-05-18_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
