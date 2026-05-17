# Phase 3: Audio Normalization (Pre-Transcription) — Research

**Researched:** 2026-05-17
**Domain:** Flutter / ffmpeg_kit_flutter_new / Dart
**Confidence:** HIGH (весь материал взят из реального кода репозитория)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D1:** Нормализация выполняется для ЛЮБОГО файла, до определения isChunked.
- **D2:** Целевой формат — `-b:a 32k -ac 1 -ar 16000 -codec:a libmp3lame`
- **D3:** `isChunked = normalizedDurationSeconds > 4500` (75 мин)
- **D4:** ProcessingScreen показывает состояние «Подготовка аудио…» во время нормализации.
- **D5:** Нормализованный tmp-файл удаляется после транскрибации.

### Claude's Discretion

- Конкретная структура NormalizedAudioFile (value object).
- Детали UI: где именно показывать ShimmerBar и текст «Подготовка аудио…».
- Нужно ли менять команду split() или оставить как есть (оценить ниже).

### Deferred Ideas (OUT OF SCOPE)

- Прогресс-бар в % для нормализации.
- Сохранение нормализованного файла для повторного использования.
</user_constraints>

---

## Summary

Phase 3 вставляет `AudioNormalizationService` как первый шаг перед чанкованием: любой формат
конвертируется ffmpeg в mp3 32kbps/16kHz/Mono. После нормализации `isChunked` рассчитывается
по длительности нормализованного файла (порог 4500 с = 75 мин), а не по sizeBytes оригинала.

Существующий паттерн `ffmpegOverride` / `probeOverride` в `AudioChunkingService` переносится
один-в-один в `AudioNormalizationService` — инфраструктура тестов уже отработана.

ProcessingScreen получает новое промежуточное UI-состояние «normalizing» между «Загрузка» и
«Распознавание» в pipeline.

**Primary recommendation:** Скопировать структуру `AudioChunkingService` (конструктор с
`ffmpegOverride`) для `AudioNormalizationService`; после нормализации перейти на `isChunked` по
длительности; в `split()` заменить `-c:a libmp3lame -b:a 128k` на `-c:a copy` (вход уже mp3).

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|---|---|---|---|
| Нормализация аудио | Service layer (AudioNormalizationService) | — | Чистый IO-сервис, не UI-логика |
| Определение isChunked | ProcessingArgs (data model) | — | Расчёт из данных нормализованного файла |
| UI состояние «normalizing» | ProcessingScreen | — | Экран владеет отображением pipeline |
| Нарезка на чанки | AudioChunkingService.split() | — | Отдельный сервис (Phase 2) |
| Очистка tmp-файлов | ChunkedTranscriptionController / ProcessingScreen | — | Тот, кто владеет lifetime файлов |

---

## 1. ffmpeg_kit_flutter_new API — Паттерн вызова

### Текущий паттерн в `audio_chunking_service.dart` (строки 97–108) [VERIFIED: codebase]

```dart
// Оборачиваем асинхронный executeAsync в Completer
final completer = Completer<void>();
await FFmpegKit.executeAsync(command, (session) async {
  final rc = await session.getReturnCode();
  if (ReturnCode.isSuccess(rc)) {
    completer.complete();
  } else {
    completer.completeError(
      const InternalException('ffmpeg завершился с ошибкой'),
    );
  }
});
await completer.future;
```

Этот паттерн полностью переносится в `AudioNormalizationService.normalize()`.

### Импорты (из `audio_chunking_service.dart`) [VERIFIED: codebase]

```dart
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/media_information.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
```

Для `AudioNormalizationService` нужны только `ffmpeg_kit.dart` и `return_code.dart`
(ffprobe в сервисе нормализации не нужен — метаданные нормализованного файла читаются
отдельно в `AudioChunkingService.getMetadata`).

### Отличия ffmpeg_kit_flutter_new от ffmpeg_kit_flutter [ASSUMED]

Пакет `ffmpeg_kit_flutter_new` — форк, поддерживаемый сообществом после архивации
оригинального `ffmpeg_kit_flutter`. Public API (`FFmpegKit`, `FFprobeKit`, `ReturnCode`,
`MediaInformation`) совпадает. Код в репозитории использует `_new` и работает — это
подтверждение совместимости.

---

## 2. Точная команда нормализации

```
-i "<inputPath>" -b:a 32k -ac 1 -ar 16000 -codec:a libmp3lame -y "<outputPath>"
```

| Флаг | Назначение |
|---|---|
| `-i "<inputPath>"` | Входной файл (любой формат из whitelist Groq) |
| `-b:a 32k` | Битрейт аудио 32 kbps — минимум для разборчивой речи |
| `-ac 1` | Моно (вдвое меньше данных, чем стерео) |
| `-ar 16000` | 16 kHz — нативная частота Whisper; выше не нужно |
| `-codec:a libmp3lame` | Энкодер mp3 (встроен в ffmpeg_kit_flutter_new) |
| `-y` | Перезаписывать выходной файл без запроса (важно для tmp-файлов) |
| `"<outputPath>"` | Временный файл, напр. `<tmpDir>/ezctx_norm_<ts>.mp3` |

**Расчёт размера:** 32 kbps × 60 с / 8 = 240 КБ/мин.
75 мин × 240 КБ = 18 000 КБ ≈ 17.6 МБ < 19 МБ лимита Groq. [VERIFIED: codebase (CONTEXT.md)]

---

## 3. split() — нужно ли менять?

### Текущая команда split() [VERIFIED: codebase]

```dart
'-i "$filePath" -f segment -segment_time ${kChunkDurationSeconds.toInt()}'
' -c:a libmp3lame -b:a 128k -ac 1 -ar 16000'
' "$tmpBase/chunk_%03d.mp3"'
```

### После нормализации

Вход `split()` — уже нормализованный mp3 32k/16kHz/Mono. Перекодирование (`libmp3lame`) —
лишняя операция, ухудшает качество (generation loss) и удваивает время нарезки.

**Рекомендация:** заменить `-c:a libmp3lame -b:a 128k -ac 1 -ar 16000` на `-c:a copy`.

```dart
// После изменения
final command =
    '-i "$filePath" -f segment -segment_time ${kChunkDurationSeconds.toInt()}'
    ' -c:a copy'
    ' "$tmpBase/chunk_%03d.mp3"';
```

**Побочный эффект:** тест `'ffmpeg-команда содержит правильные параметры кодирования'`
(строка 133 в `audio_chunking_service_test.dart`) проверяет `-c:a libmp3lame`, `-b:a 128k`,
`-ac 1`, `-ar 16000` — все эти проверки нужно удалить/заменить на `-c:a copy`.

**Новый порог `kChunkDurationSeconds`:** текущий 1200 с (20 мин) → нужно обновить до
4500 с (75 мин), т.к. теперь файлы нормализованы и 75 мин = ~17.6 МБ < 19 МБ.

---

## 4. Pipeline Integration — пошаговая схема

### Текущий flow (ProcessingScreen.didChangeDependencies)

```
args → _isChunked = args.isChunked (sizeBytes ≥ 19 MB)
     ↓
if _isChunked → ChunkedTranscriptionController.start(_file!)
else → TranscriptionController.start(_file!)
```

### Новый flow

```
args → ProcessingScreen.didChangeDependencies
     ↓
setState(normalizing = true)   // показать «Подготовка аудио…»
     ↓
AudioNormalizationService.normalize(file.path) → NormalizedAudioFile
     ↓
_isChunked = normalizedFile.durationSeconds > kChunkThresholdSeconds
     ↓
setState(normalizing = false)
     ↓
if _isChunked → ChunkedTranscriptionController.start(normalizedFile)
else → TranscriptionController.start via SelectedAudioFile(normalizedFile.path)
```

### Конкретные изменения в ProcessingScreen

1. Добавить поле `bool _normalizing = false` и `NormalizedAudioFile? _normalizedFile`.
2. В `didChangeDependencies` вынести запуск в отдельный `Future<void> _startProcessing()`,
   вызвать `WidgetsBinding.instance.addPostFrameCallback((_) => _startProcessing())`.
3. `_startProcessing()` — async:
   - `setState(() => _normalizing = true)`
   - `_normalizedFile = await AudioNormalizationService().normalize(file.path)`
   - `_isChunked = _normalizedFile!.durationSeconds > AppConstants.kChunkThresholdSeconds`
   - `setState(() => _normalizing = false)`
   - ветвление на chunked / single как сейчас, но передать `_normalizedFile!.path`
4. В `build()` / `_buildChunkedBody()` добавить ветку `if (_normalizing)` → показать
   `ShimmerBar` + текст «Подготовка аудио…».
5. В `dispose()` удалить `_normalizedFile` (tmp-файл).
6. Pipeline шаги: «Загрузка» → «**Подготовка аудио**» → «Распознавание» → «Готово».

### Передача нормализованного файла в chunked-путь

`ChunkedTranscriptionController.start()` принимает `SelectedAudioFile`. Нужно либо:
- **Вариант A (рекомендуется):** создать `SelectedAudioFile` из `NormalizedAudioFile`
  (`path`, `name`, `sizeBytes`, `extension = 'mp3'`).
- **Вариант B:** изменить сигнатуру `start()` — более инвазивно.

---

## 5. Test Strategy — AudioNormalizationService

### Паттерн из AudioChunkingService [VERIFIED: codebase]

```dart
// Конструктор с override
const AudioNormalizationService({
  Future<void> Function(String command)? ffmpegOverride,
}) : _ffmpegOverride = ffmpegOverride;

// В продакшне — реальный FFmpegKit.executeAsync (Completer-паттерн)
// В тестах — ffmpegOverride
```

### Тест-файл: `test/features/transcription/audio_normalization_service_test.dart`

```dart
group('AudioNormalizationService.normalize', () {
  test('команда содержит правильные флаги', () async {
    String? capturedCommand;
    final svc = AudioNormalizationService(
      ffmpegOverride: (cmd) async { capturedCommand = cmd; },
    );

    // Создаём реальный tmp-файл, чтобы File.statSync() не падал
    final tmp = await File('${Directory.systemTemp.path}/input.ogg').create();
    addTearDown(() => tmp.deleteSync());

    final result = await svc.normalize(tmp.path);

    expect(capturedCommand, contains('-b:a 32k'));
    expect(capturedCommand, contains('-ac 1'));
    expect(capturedCommand, contains('-ar 16000'));
    expect(capturedCommand, contains('-codec:a libmp3lame'));
    expect(capturedCommand, contains('-y'));
    expect(result.path, endsWith('.mp3'));
  });

  test('ошибка ffmpeg → InternalException', () async {
    final svc = AudioNormalizationService(
      ffmpegOverride: (_) async {
        throw const InternalException('ffmpeg завершился с ошибкой');
      },
    );
    final tmp = await File('${Directory.systemTemp.path}/input.m4a').create();
    addTearDown(() => tmp.deleteSync());

    await expectLater(
      () => svc.normalize(tmp.path),
      throwsA(isA<InternalException>()),
    );
  });
});
```

### Обновление audio_chunking_service_test.dart

Тест «ffmpeg-команда содержит правильные параметры кодирования» (строка 133) проверяет
`-c:a libmp3lame`, `-b:a 128k` и т.д. После замены на `-c:a copy` эти expects нужно заменить:

```dart
expect(capturedCommand, contains('-c:a copy'));
expect(capturedCommand, contains('-f segment'));
expect(capturedCommand, contains('-segment_time 4500')); // новый порог 75 мин
expect(capturedCommand, contains('chunk_%03d.mp3'));
// убрать: contains('-c:a libmp3lame'), contains('-b:a 128k'), contains('-ac 1'), contains('-ar 16000')
```

---

## 6. isChunked Migration — sizeBytes → durationSeconds

### Текущий код (processing_args.dart, строка 20) [VERIFIED: codebase]

```dart
bool get isChunked => file.sizeBytes >= 19 * 1024 * 1024;
```

### Новый подход

`isChunked` теперь не нужен в `ProcessingArgs` — решение принимается внутри
`ProcessingScreen._startProcessing()` после нормализации:

```dart
_isChunked = _normalizedFile!.durationSeconds > AppConstants.kChunkThresholdSeconds;
```

**В `ProcessingArgs`:** поле `isChunked` можно либо удалить, либо оставить как deprecated
(не используется после Phase 3). Удаление чище — `ProcessingScreen` больше не читает
`args.isChunked` (строка 89 `processing_screen.dart`).

**`AppConstants` — новые константы:**

```dart
/// Порог для isChunked (75 мин = 4500 с).
static const int kChunkThresholdSeconds = 4500;

/// Порог чанка в секундах при нарезке нормализованного файла.
static const double kChunkDurationSeconds = 4500.0; // заменяет 1200.0 в audio_chunking_service.dart
```

Примечание: `kChunkDurationSeconds` сейчас объявлена как top-level константа в
`audio_chunking_service.dart` (строка 15). Перенести в `AppConstants` — правильно для
единого источника правды. Или оставить в сервисе — менее важно.

---

## 7. NormalizedAudioFile — value object

```dart
/// Результат нормализации: путь к tmp mp3-файлу и его длительность.
class NormalizedAudioFile {
  final String path;
  final double durationSeconds;

  const NormalizedAudioFile({required this.path, required this.durationSeconds});
}
```

Длительность читается через `AudioChunkingService.getMetadata(path).durationSeconds`
после нормализации — либо `AudioNormalizationService` вызывает ffprobe сам
(через свой `probeOverride`), либо делегирует существующему `AudioChunkingService`.

**Рекомендация:** `AudioNormalizationService.normalize()` вызывает `getMetadata` через
существующий `AudioChunkingService` (инжектируется в конструктор или создаётся внутри).
Это позволяет протестировать оба шага независимо.

---

## 8. Поддерживаемые форматы Groq

Список из `app_constants.dart` (строка 19–29) [VERIFIED: codebase]:

```
flac, mp3, mp4, mpeg, mpga, m4a, ogg, wav, webm
```

Список в CONTEXT.md правильный. Формат `flac` присутствует в `supportedAudioExtensions` —
всё совпадает.

---

## Common Pitfalls

### Pitfall 1: Completer и executeAsync — не ждать без `await completer.future`

**Что идёт не так:** Если забыть `await completer.future`, метод вернётся раньше,
чем ffmpeg завершится. Файл не будет создан.

**Как избежать:** Всегда писать два `await`:
```dart
await FFmpegKit.executeAsync(command, (session) async { ... completer.complete(); });
await completer.future;
```

### Pitfall 2: Путь с пробелами без кавычек

**Что идёт не так:** Пути Android (`/data/user/0/…`) обычно без пробелов, но имена файлов
пользователя могут содержать пробелы. ffmpeg разобьёт путь по пробелу.

**Как избежать:** Всегда оборачивать пути в `"…"` в строке команды:
```dart
'-i "$inputPath" … "$outputPath"'
```
(уже делается в `audio_chunking_service.dart` — паттерн подтверждён.)

### Pitfall 3: `-y` обязателен для tmp-файлов

**Что идёт не так:** При повторной нормализации (retry) ffmpeg встретит существующий файл
и зависнет, ожидая y/n на stdin (stdin в Android не работает — процесс повиснет навсегда).

**Как избежать:** Всегда добавлять флаг `-y` в команду нормализации.

### Pitfall 4: getMetadata после нормализации — не до

**Что идёт не так:** `ProcessingArgs.metadata` читается ДО нормализации и содержит
длительность оригинала. После нормализации длительность может незначительно отличаться
(ffmpeg пересчитывает контейнер).

**Как избежать:** Всегда читать метаданные (durationSeconds) из нормализованного файла,
а не из `ProcessingArgs.metadata`.

### Pitfall 5: split() с `-c:a copy` и mp3-сегментацией

**Что идёт не так:** `-f segment` с `-c:a copy` для mp3 работает корректно (mp3 — CBR,
поэтому разрезание по времени не вызывает артефактов). Потенциальная проблема:
некоторые устаревшие сборки ffmpeg плохо обрабатывают segment+copy для mp3. В
ffmpeg_kit_flutter_new встроена современная версия ffmpeg — проблем не ожидается.

**Как избежать:** Добавить интеграционный тест с реальным файлом (smoke test).

### Pitfall 6: Android tmp-файлы и очистка

**Что идёт не так:** Если `ProcessingScreen` снимается до завершения нормализации (пользователь
нажал «Закрыть»), tmp-файл остаётся в `getTemporaryDirectory()`.

**Как избежать:** Хранить ссылку на `_normalizedFile` в `State`, в `dispose()` вызывать
`_normalizedFile?.delete()`. Аналогично — в `ChunkedTranscriptionController` по завершении.

---

## Architecture Patterns

### Рекомендуемая структура AudioNormalizationService

```dart
// lib/features/transcription/audio_normalization_service.dart

import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';

import 'package:ezctx/core/error/app_exception.dart';
import 'audio_chunking_service.dart'; // для getMetadata
import 'normalized_audio_file.dart';

class AudioNormalizationService {
  final Future<void> Function(String command)? _ffmpegOverride;
  final AudioChunkingService _chunkingService;

  const AudioNormalizationService({
    Future<void> Function(String command)? ffmpegOverride,
    AudioChunkingService? chunkingService,
  })  : _ffmpegOverride = ffmpegOverride,
        _chunkingService = chunkingService ?? const AudioChunkingService();

  /// Конвертирует [inputPath] в mp3 32k/Mono/16kHz во временную директорию.
  /// Возвращает [NormalizedAudioFile] с путём и длительностью.
  Future<NormalizedAudioFile> normalize(String inputPath) async {
    final tmpDir = (await getTemporaryDirectory()).path;
    final outPath =
        '$tmpDir/ezctx_norm_${DateTime.now().millisecondsSinceEpoch}.mp3';

    final command =
        '-i "$inputPath" -b:a 32k -ac 1 -ar 16000 -codec:a libmp3lame -y "$outPath"';

    if (_ffmpegOverride != null) {
      await _ffmpegOverride(command);
    } else {
      final completer = Completer<void>();
      await FFmpegKit.executeAsync(command, (session) async {
        final rc = await session.getReturnCode();
        if (ReturnCode.isSuccess(rc)) {
          completer.complete();
        } else {
          completer.completeError(
            const InternalException('ffmpeg: нормализация завершилась с ошибкой'),
          );
        }
      });
      await completer.future;
    }

    final meta = await _chunkingService.getMetadata(outPath);
    return NormalizedAudioFile(
      path: outPath,
      durationSeconds: meta.durationSeconds,
    );
  }
}
```

### Схема потока данных

```
[User: выбрал файл]
        │
        ▼
ProcessingScreen.didChangeDependencies()
        │
        ▼ (setState: _normalizing = true)
AudioNormalizationService.normalize(file.path)
        │   ffmpeg: -b:a 32k -ac 1 -ar 16000 -codec:a libmp3lame -y
        ▼
NormalizedAudioFile(path, durationSeconds)
        │
        ├─ isChunked = durationSeconds > 4500
        │
        ├─ false ──► TranscriptionController.start(SelectedAudioFile from normalizedPath)
        │                     │
        │                     ▼
        │            GroqApiService.transcribe(normalizedPath)
        │
        └─ true ───► ChunkedTranscriptionController.start(SelectedAudioFile from normalizedPath)
                              │
                              ▼
                     AudioChunkingService.split(normalizedPath)
                     ffmpeg: -f segment -segment_time 4500 -c:a copy
                              │
                              ▼
                     [chunk_000.mp3, chunk_001.mp3, ...]
                              │
                              ▼
                     GroqApiService.transcribeChunk(×N)
```

---

## Validation Architecture

### Test Framework

| Property | Value |
|---|---|
| Framework | flutter_test (встроен во Flutter SDK) |
| Config file | нет отдельного — запуск через flutter test |
| Quick run command | `flutter test test/features/transcription/audio_normalization_service_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req | Behavior | Test Type | Команда | Файл существует? |
|---|---|---|---|---|
| Нормализация | Команда ffmpeg содержит правильные флаги | unit | `flutter test test/features/transcription/audio_normalization_service_test.dart` | ❌ Wave 0 |
| Нормализация | Ошибка ffmpeg → InternalException | unit | см. выше | ❌ Wave 0 |
| isChunked | durationSeconds > 4500 → true | unit | `flutter test test/features/transcription/processing_args_test.dart` | ❌ Wave 0 |
| split() | Команда содержит `-c:a copy` | unit | `flutter test test/features/transcription/audio_chunking_service_test.dart` | ✅ (нужно обновить) |

### Wave 0 Gaps

- [ ] `test/features/transcription/audio_normalization_service_test.dart` — новый файл
- [ ] Обновить `test/features/transcription/audio_chunking_service_test.dart` — заменить проверки `-c:a libmp3lame`, `-b:a 128k`, `-ac 1`, `-ar 16000` на `-c:a copy`; обновить `-segment_time` с 1200 на 4500

---

## Environment Availability

Step 2.6: SKIPPED — ffmpeg_kit_flutter_new встроен в APK; внешних зависимостей нет.

---

## Security Domain

Фаза работает только с локальными tmp-файлами. Внешних запросов нет. API-ключ не
затрагивается. ASVS-категории не применимы к этой фазе.

---

## Open Questions

1. **Как ChunkedTranscriptionController принимает путь нормализованного файла?**
   - Что знаем: `start()` принимает `SelectedAudioFile`.
   - Что неясно: нужно ли менять сигнатуру или конструировать `SelectedAudioFile` из нормализованного пути.
   - Рекомендация: конструировать `SelectedAudioFile` (Вариант A, минимально инвазивно).

2. **Куда перенести константу `kChunkDurationSeconds`?**
   - Сейчас: top-level в `audio_chunking_service.dart` (1200.0).
   - Новое значение: 4500.0.
   - Рекомендация: перенести в `AppConstants` для единого источника правды.

---

## Sources

### Primary (HIGH confidence)
- `lib/features/transcription/audio_chunking_service.dart` — паттерн executeAsync + ffmpegOverride
- `lib/features/transcription/processing_args.dart` — текущий isChunked
- `lib/ui/screens/processing_screen.dart` — текущий pipeline flow
- `test/features/transcription/audio_chunking_service_test.dart` — паттерн тестирования
- `.planning/phases/03-audio-normalization/03-CONTEXT.md` — locked decisions
- `lib/core/constants/app_constants.dart` — whitelist форматов Groq

### Tertiary (LOW confidence)
- Поведение `-c:a copy` с `-f segment` для mp3: `[ASSUMED]` — обосновано природой CBR mp3,
  но не проверено на реальном устройстве Android.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|---|---|---|
| A1 | ffmpeg_kit_flutter_new Public API совпадает с ffmpeg_kit_flutter | ffmpeg_kit_flutter_new API | Потребуется изменить импорты или сигнатуры вызовов |
| A2 | `-c:a copy` с `-f segment` корректно работает для mp3 в ffmpeg_kit_flutter_new на Android | split() изменения | Чанки могут быть повреждены; fallback — оставить `-c:a libmp3lame` |

---

## RESEARCH COMPLETE
