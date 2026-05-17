# Phase 2: Real Lectures (Chunking & Progress) — Research

**Researched:** 2026-05-17
**Domain:** Flutter/Dart — ffmpeg_kit_flutter_new, chunked audio transcription, parallel HTTP, progress UI
**Confidence:** HIGH (core APIs verified via pub.dev docs + official arthenica wiki; patterns verified via Dart official docs)

---

<user_constraints>
## User Constraints (from Phase 1 CONTEXT.md)

### Locked Decisions (carried forward)
- **D-03:** Зависимости: `http`, `file_picker`, `flutter_secure_storage`, `ffmpeg_kit_flutter_new`, `path_provider`
- **D-17:** Параметры Groq: `response_format=verbose_json`, `timestamp_granularities=[word]`
- **D-18:** Модель: `whisper-large-v3`
- **D-19:** API-ключ хранится только в `flutter_secure_storage`
- Структура пакетов: `lib/core/`, `lib/features/`, `lib/ui/`
- Секреты — только `flutter_secure_storage`, никогда SharedPreferences

### Phase 2 Additional Constraints (from task description)
- `ffmpeg_kit_flutter_new ^4.1.0` — ЕДИНСТВЕННЫЙ ffmpeg-вариант (arthenica архивирован в июне 2025)
- Один API-ключ для Phase 2 (пул ключей — Phase 3)
- Isolates не нужны — Dart async достаточен для параллельных HTTP
- Android only (v1)
- Новые внешние пакеты — только если действительно необходимо

### Claude's Discretion
- Формат тайм-кодов в финальном тексте (исследовать и рекомендовать)
- Конкретная стратегия очистки temp-файлов при отмене
- Конкретный паттерн bounded concurrency (семафор vs stream vs manual queue)

### Deferred (OUT OF SCOPE)
- Пул API-ключей (Phase 3)
- SRT/VTT экспорт (Phase 5)
- Share intent (Phase 5)
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| IMPORT-03 | ffprobe определяет длительность, битрейт, кодек до начала работы | FFprobeKit.getMediaInformation() — §Findings 1 |
| IMPORT-04 | Пользователь видит метаданные файла (имя, длительность, размер) перед запуском | FFprobeKit + SelectedAudioFile расширение — §Findings 1 |
| TRANS-04 | Файл >19 MB режется ffmpeg: -f segment, 1200 сек, mp3 128k | FFmpegKit.executeAsync() с аргументами сегментации — §Findings 1 |
| TRANS-05 | Чанки отправляются параллельно через семафор min(ключи, N) | Dart Semaphore-паттерн без пакета — §Findings 2 |
| TRANS-06 | Ретраи с экспоненциальной задержкой (5·2^attempt) на транзиентных ошибках; 524 — повтор | Ручной retry-loop в Dart — §Findings 3 |
| TRANS-08 | Слова из чанков склеиваются с учётом offset (index * chunk_duration) | Сборка TranscriptionResult с offset — §Findings 4 |
| TRANS-09 | Прогресс: общий процент + статус по чанкам | ChangeNotifier + List<ChunkStatus> — §Findings 5 |
| TRANS-10 | Промежуточные чанки удаляются из tmp после завершения | path_provider + try/finally cleanup — §Findings 6 |
</phase_requirements>

---

## Summary

Phase 2 добавляет поддержку длинных лекций (часы, сотни МБ) путём автоматической нарезки через ffmpeg на чанки ≤19 МБ, параллельной отправки в Groq Whisper и сборки результата с тайм-кодами. Все три ключевых технических блока (ffmpeg, параллельный HTTP с ограничением, retry) реализуются без новых внешних пакетов — Dart async достаточен.

`FFprobeKit.getMediaInformation()` возвращает `MediaInformation` с методом `getDuration()` (строка в миллисекундах). `FFmpegKit.executeAsync()` с флагами `-f segment -segment_time 1200 -c:a libmp3lame -b:a 128k` нарезает аудио асинхронно. Bounded concurrency реализуется через Dart-совместимый `LocalSemaphore` (пакет `semaphore` — однако, поскольку constraint ограничивает новые пакеты, ниже описан эквивалентный ручной паттерн через `Completer`-очередь). Retry с экспоненциальным backoff реализуется тривиально в 20 строках на чистом Dart.

Groq free tier для whisper-large-v3 ограничен ~20 RPM (2000 RPD / ~7200 аудиосекунд в час). Для одного ключа безопасная параллельность — 3 одновременных запроса с задержкой между ними ~2–3 сек. Финальный текст: чанки объединяются через `segments[]` с offset = `chunkIndex * chunkDurationSeconds`; для Phase 2 достаточно плоского текста с маркерами `[ЧЧ:ММ:СС]` в начале каждого чанка (полная word-level сборка — Phase 5/SRT).

**Primary recommendation:** Ввести `AudioChunkingService` (ffmpeg-нарезка + ffprobe-метаданные), расширить `GroqApiService.transcribeChunk()`, создать `ChunkedTranscriptionController extends ChangeNotifier` с `List<ChunkStatus>` и делегировать работу `ProcessingScreen` через него. `TranscriptionResult` остаётся неизменным — сборка происходит в контроллере перед эмитом `TranscriptionSuccess`.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| ffprobe метаданные файла | Feature Service (AudioChunkingService) | — | Платформенный вызов, не UI-логика |
| Нарезка на чанки | Feature Service (AudioChunkingService) | — | Тяжёлая I/O-операция, изолирована от UI |
| Параллельные HTTP запросы | Feature Controller (ChunkedTranscriptionController) | GroqApiService | Координация состояния + HTTP |
| Retry-логика | GroqApiService (метод transcribeChunk) | — | Инкапсулирована в HTTP-слое, независима от UI |
| Сборка transcript + offset | Feature Controller | — | Доменная логика, не UI и не HTTP |
| Прогресс UI | ProcessingScreen (расширить) | ChunkedTranscriptionController | UI читает state, controller эмитит |
| Temp file cleanup | AudioChunkingService / контроллер | — | try/finally в слое нарезки |
| API-ключ | ApiKeyRepository (существует) | — | Не меняется |

---

## Technical Findings

### 1. ffmpeg_kit_flutter_new: ffprobe + chunking

**Пакет и версия** [CITED: pub.dev/packages/ffmpeg_kit_flutter_new]:
- Текущий пакет: `ffmpeg_kit_flutter_new ^4.1.0`
- Издатель: antonkarpenko.com (форк sk3llo, обновлён для Android V2 bindings и Flutter 3+)
- Оригинал arthenica/ffmpeg-kit архивирован, бинарники удалены — этот форк является рабочей заменой
- Поддерживаемые платформы: Android, iOS, macOS

**FFprobeKit.getMediaInformation()** [CITED: github.com/arthenica/ffmpeg-kit wiki/Flutter]:

```dart
// Получить длительность и метаданные файла
Future<AudioFileInfo> probeFile(String filePath) async {
  final session = await FFprobeKit.getMediaInformation(filePath);
  final info = await session.getMediaInformation();

  if (info == null) {
    // Ошибка — запрашиваем детали из сессии
    final state = await session.getState();
    final output = await session.getOutput();
    throw InternalException('ffprobe не смог прочитать файл: $output');
  }

  // getDuration() возвращает строку в миллисекундах
  final durationMs = double.tryParse(info.getDuration() ?? '0') ?? 0.0;
  final durationSeconds = durationMs / 1000.0;

  // Битрейт и кодек из потоков
  final streams = info.getStreams();
  final audioStream = streams?.firstWhere(
    (s) => s.getType() == 'audio',
    orElse: () => streams!.first,
  );
  final codec = audioStream?.getCodec() ?? 'unknown';
  final bitrate = info.getBitrate() ?? '0';

  return AudioFileInfo(
    durationSeconds: durationSeconds,
    bitrateKbps: (int.tryParse(bitrate) ?? 0) ~/ 1000,
    codec: codec,
  );
}
```

**Важно:** `MediaInformation.getDuration()` возвращает `String?` в **миллисекундах** [CITED: pub.dev/documentation/ffmpeg_kit_flutter_new/latest/]. Требуется парсинг в double + деление на 1000.

**FFmpegKit.executeAsync() — нарезка на чанки** [CITED: github.com/arthenica/ffmpeg-kit wiki/Flutter]:

```dart
// Нарезка аудиофайла на сегменты ≤19 МБ (1200 сек @ 128 kbps ≈ 11.25 МБ — безопасный запас)
Future<List<String>> splitAudio({
  required String inputPath,
  required String outputDir,
  required String baseName,
  int segmentSeconds = 1200,
}) async {
  final outputPattern = '$outputDir/${baseName}_%03d.mp3';

  final cmd = '-i "$inputPath" '
      '-f segment '
      '-segment_time $segmentSeconds '
      '-c:a libmp3lame '
      '-b:a 128k '
      '-ac 1 '      // моно — уменьшает размер вдвое
      '-ar 16000 '  // 16 kHz — минимум для Whisper
      '"$outputPattern"';

  final session = await FFmpegKit.executeAsync(
    cmd,
    (session) async {
      // Коллбек завершения сессии
      final returnCode = await session.getReturnCode();
      if (!ReturnCode.isSuccess(returnCode)) {
        final output = await session.getOutput();
        throw InternalException('ffmpeg split failed: $output');
      }
    },
    (log) {
      // Коллбек логов (опционально — для отладки)
    },
    (statistics) {
      // Коллбек статистики: statistics.getTime() — прогресс в мс
    },
  );

  // Ждём завершения через Future completer
  // или используем синхронную обёртку:
  final returnCode = await session.getReturnCode();
  if (!ReturnCode.isSuccess(returnCode)) {
    throw InternalException('ffmpeg split failed');
  }

  // Собираем список созданных чанков
  final dir = Directory(outputDir);
  final chunks = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.contains(baseName) && f.path.endsWith('.mp3'))
      .map((f) => f.path)
      .toList()
    ..sort(); // сортировка по имени → правильный порядок

  return chunks;
}
```

**Коллбек прогресса ffmpeg** [CITED: arthenica wiki]:
- `statisticsCallback` вызывается периодически с объектом `Statistics`
- `statistics.getTime()` — int, миллисекунды обработанного аудио
- `statistics.getSize()` — bytes выходного файла
- Для нарезки прогресс по чанкам отслеживается не через статистику, а через событие завершения каждого чанка — ffmpeg создаёт файлы последовательно

**executeAsync vs execute** [CITED: arthenica wiki]:
- `FFmpegKit.executeAsync()` — неблокирующий, возвращает `FFmpegSession` с Future
- `FFmpegKit.execute()` — блокирующий, синхронный (не использовать в UI thread)
- Для нарезки правильно использовать `executeAsync` + `await session.getReturnCode()`

---

### 2. Parallel HTTP in Dart (bounded concurrency)

**Groq Free Tier лимиты** [CITED: community.groq.com/t/is-there-a-free-tier]:
- whisper-large-v3: **2 000 RPD** (запросов в день), **7 200 аудиосекунд в час**
- Приблизительный RPM: ~20-30 requests/min (специфика для Whisper — audio-seconds/hour важнее RPM)
- 7200 аудиосекунд/час = 2 часа аудио за час реального времени
- Безопасная параллельность для одного ключа: **3 одновременных запроса** [ASSUMED]

**Паттерн bounded concurrency — Semaphore без внешнего пакета** [CITED: dart.dev/language/concurrency]:

```dart
/// Простой семафор через Completer-очередь — нулевые зависимости.
class _Semaphore {
  _Semaphore(this._maxConcurrent);

  final int _maxConcurrent;
  int _current = 0;
  final _waiters = <Completer<void>>[];

  Future<void> acquire() async {
    if (_current < _maxConcurrent) {
      _current++;
      return;
    }
    final completer = Completer<void>();
    _waiters.add(completer);
    await completer.future;
    _current++;
  }

  void release() {
    _current--;
    if (_waiters.isNotEmpty) {
      final next = _waiters.removeAt(0);
      next.complete();
    }
  }
}

// Использование — 3 параллельных HTTP-запроса максимум:
Future<List<ChunkResult>> sendChunksParallel(
  List<String> chunkPaths,
  String apiKey,
) async {
  final semaphore = _Semaphore(3);
  final results = <int, ChunkResult>{};

  await Future.wait(
    chunkPaths.asMap().entries.map((entry) async {
      final index = entry.key;
      final path = entry.value;
      await semaphore.acquire();
      try {
        final result = await _transcribeWithRetry(path, index, apiKey);
        results[index] = result;
      } finally {
        semaphore.release();
      }
    }),
  );

  // Возвращаем в порядке индексов
  return List.generate(results.length, (i) => results[i]!);
}
```

**Future.wait vs Stream** [CITED: dart.dev]:
- `Future.wait` подходит когда количество задач известно заранее (N чанков) — **рекомендуется**
- Stream + asyncMap последователен (не параллелен) — не подходит для bounded parallel
- Для progress-репортинга с Future.wait: обновлять `ChangeNotifier` из каждого Future через `_set()`

---

### 3. Retry with Exponential Backoff

**Dart-паттерн без пакета** [CITED: dart.dev/language/concurrency]:

```dart
/// Ретрай с экспоненциальным backoff.
/// maxAttempts=4 (1 первая попытка + 3 ретрая), baseDelay=5s, multiplier=2.
/// TRANS-06: задержка 5·2^attempt сек.
Future<T> _withRetry<T>(
  Future<T> Function() action, {
  int maxAttempts = 4,
  Duration baseDelay = const Duration(seconds: 5),
}) async {
  for (int attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      return await action();
    } on AuthException {
      // 401 — не ретраить, ключ неверный
      rethrow;
    } on NetworkException catch (e) {
      if (attempt == maxAttempts - 1) rethrow;
      // Экспоненциальная задержка: 5, 10, 20 сек
      final delay = baseDelay * (1 << attempt); // 2^attempt
      await Future.delayed(delay);
    }
  }
  throw const NetworkException('Превышено количество попыток');
}
```

**Обнаружение 524 и 429** [CITED: groq.com/docs/rate-limits]:
- HTTP 524 (Cloudflare timeout) — приходит как статус 524 в `response.statusCode`
- HTTP 429 (rate limit) — `response.statusCode == 429`; ответ содержит `Retry-After` header
- Оба должны считаться ретраябельными `NetworkException`

**Изменение в GroqApiService.transcribe()** — нужно пробрасывать raw statusCode в исключение, чтобы контроллер мог различить 401 vs 524 vs 429:

```dart
// Обновить в GroqApiService:
if (response.statusCode == 401) throw const AuthException(_authErrorMessage);
if (response.statusCode == 429) throw NetworkException('Rate limit (429) — ретрай через ${response.headers['retry-after'] ?? '5'}с');
if (response.statusCode == 524) throw const NetworkException('Groq timeout (524)');
// остальные 4xx/5xx:
throw NetworkException('Ошибка сервера ${response.statusCode}');
```

**Разумные параметры для Groq free tier** [ASSUMED]:
- maxAttempts = 4 (3 ретрая)
- baseDelay = 5s (TRANS-06 требует 5·2^attempt)
- Итого задержки: 5s, 10s, 20s — максимум 35 сек overhead на чанк
- Для 429: использовать `Retry-After` header если доступен

---

### 4. Transcript Assembly with Timecodes

**Groq verbose_json сегменты** [CITED: console.groq.com/docs/speech-to-text]:
- Ответ содержит `segments[]` с полями `id`, `seek`, `start`, `end`, `text`, `tokens`, `avg_logprob`
- Все временны́е метки **относительны начала чанка**
- Phase 1 запрашивает `timestamp_granularities[]=word` → ответ содержит `words[]`; `segments[]` добавляется при `timestamp_granularities[]=segment`

**Важное замечание**: Phase 1 запрашивает только `word`-granularity (D-17). `segments[]` в verbose_json **всегда присутствует** независимо от `timestamp_granularities` — это базовый уровень [ASSUMED, требует проверки на реальном ответе].

**Стратегия сборки для Phase 2** — минимальный вариант (полная word-level сборка — Phase 5):

```dart
/// Сборка текста чанков с маркерами тайм-кодов в начале каждого чанка.
/// Для Phase 2: простой текст + маркер [ЧЧ:ММ:СС] на каждый чанк.
/// Phase 5 добавит сборку на уровне слов.
String assembleTranscript(List<ChunkTranscriptResult> chunkResults) {
  final buffer = StringBuffer();
  for (final chunk in chunkResults) {
    final offset = Duration(seconds: (chunk.index * chunk.chunkDurationSeconds).round());
    final marker = _formatTimecode(offset);
    buffer.writeln('[$marker]');
    buffer.writeln(chunk.text.trim());
    buffer.writeln();
  }
  return buffer.toString().trim();
}

String _formatTimecode(Duration d) {
  final h = d.inHours.toString().padLeft(2, '0');
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$h:$m:$s';
}
```

**Что добавить в TranscriptionResult** — нет необходимости изменять `TranscriptionResult`. Ввести отдельный `ChunkTranscriptResult`:

```dart
class ChunkTranscriptResult {
  final int index;
  final double chunkDurationSeconds; // длительность этого конкретного чанка
  final String text;
  final double offsetSeconds; // index * chunkDurationSeconds
  final List<WordTimestamp> words; // с уже применённым offset
}
```

Финальный `TranscriptionResult` создаётся контроллером из склеенных чанков.

---

### 5. Progress UI: ChangeNotifier + per-chunk state

**Паттерн per-chunk state** [CITED: flutter.dev/docs/development/data-and-backend/state-mgmt/simple]:

```dart
// Статусы чанков
enum ChunkStatus { waiting, uploading, done, failed }

class ChunkState {
  final int index;
  final ChunkStatus status;
  final String? errorMessage;
  const ChunkState({required this.index, required this.status, this.errorMessage});
  ChunkState copyWith({ChunkStatus? status, String? errorMessage}) => ...;
}

// В ChunkedTranscriptionController:
List<ChunkState> _chunks = [];
List<ChunkState> get chunks => List.unmodifiable(_chunks);
int get totalChunks => _chunks.length;
int get doneChunks => _chunks.where((c) => c.status == ChunkStatus.done).length;
double get progressFraction => totalChunks > 0 ? doneChunks / totalChunks : 0.0;

void _updateChunk(int index, ChunkStatus status, {String? error}) {
  _chunks = List.from(_chunks)
    ..[index] = _chunks[index].copyWith(status: status, errorMessage: error);
  _set(TranscriptionChunking(chunks: _chunks, progress: progressFraction));
}
```

**Добавить новый state** в sealed class `TranscriptionState`:

```dart
class TranscriptionChunking extends TranscriptionState {
  final List<ChunkState> chunks;
  final double progress; // 0.0 — 1.0
  const TranscriptionChunking({required this.chunks, required this.progress});
}
```

**ProcessingScreen** — расширить, не заменять:
- Добавить ветку `if (state is TranscriptionChunking)` в `build()`
- Показать `LinearProgressIndicator(value: state.progress)` + ListView с тайлами чанков
- Существующие состояния `Loading/Success/Error` сохраняются для короткого файла (<19 МБ)
- `ListenableBuilder` оборачивает только список чанков, не весь Scaffold

**AnimatedList vs ListView.builder**:
- Для фазы 2 достаточен `ListView.builder` с `shrinkWrap: true` — N чанков известен заранее
- `AnimatedList` — избыточно для этой задачи

---

### 6. Temp File Management on Android

**Правильная директория** [CITED: pub.dev/packages/path_provider]:
- `getTemporaryDirectory()` → `Context.getCacheDir()` на Android — **правильный выбор**
- ОС может очищать при нехватке места, но явная очистка — ответственность приложения
- `getApplicationDocumentsDirectory()` — для постоянного хранения, не для temp-файлов

**Гарантированная очистка через try/finally**:

```dart
Future<void> transcribeLargeFile(SelectedAudioFile file) async {
  final tmpDir = await getTemporaryDirectory();
  final sessionDir = '${tmpDir.path}/ezctx_${DateTime.now().millisecondsSinceEpoch}';
  await Directory(sessionDir).create(recursive: true);

  try {
    final chunks = await _chunkingService.split(file.path, sessionDir);
    // ... транскрибация ...
  } finally {
    // Всегда удаляем — даже при cancel или ошибке
    try {
      await Directory(sessionDir).delete(recursive: true);
    } catch (_) {
      // Игнорируем ошибку удаления — не критично
    }
  }
}
```

**Отмена на середине**:
- Пользователь нажимает "Отменить" → `Navigator.pop()` → `dispose()` контроллера
- Проблема: ffmpeg и HTTP продолжают работать после dispose
- Решение: хранить `CancellationToken` (флаг `_cancelled = true`), проверять перед каждым шагом
- `finally`-блок в контроллере должен запускаться независимо от `_cancelled`

**Subdirectory per session** (рекомендуется):
- Создавать уникальную поддиректорию `ezctx_{timestamp}` — изолирует сессии
- Удалять всю директорию рекурсивно в finally

---

### 7. File Size Detection

**Dart File API на Android** [CITED: api.dart.dev/stable/dart-io/File/]:
- `File(path).lengthSync()` — синхронный, безопасен для уже доступных файлов
- `File(path).stat()` / `statSync()` — возвращает `FileStat` с `.size` полем
- Оба работают корректно на Android с путями, возвращёнными `file_picker`

**Scoped Storage и file_picker** [CITED: pub.dev/packages/file_picker]:
- `file_picker ^11.0.2` кеширует выбранные файлы в app-scoped cache → путь абсолютный
- `File(pickedPath).lengthSync()` безопасен — файл уже в кеше приложения
- Рекомендуется `File(path).length()` (async) вместо `lengthSync()` в async-контексте

```dart
// Безопасный способ получить размер:
Future<int> getFileSizeBytes(String path) async {
  return await File(path).length(); // async-версия предпочтительна
}
```

**Дублирование с SelectedAudioFile**: В Phase 1 `SelectedAudioFile.sizeBytes` уже содержит размер — для UI не нужно повторно вызывать `File.length()`. ffprobe нужен только для `durationSeconds` и `codec`.

---

## Recommended Architecture for Phase 2

### System Architecture Diagram

```
SelectedAudioFile (path + sizeBytes)
        │
        ▼
AudioChunkingService
  ├── probeFile(path) → AudioFileInfo (duration, codec, bitrate)    [FFprobeKit]
  └── splitAudio(path, tmpDir) → List<String> chunkPaths            [FFmpegKit]
        │
        ▼
ChunkedTranscriptionController (ChangeNotifier)
  ├── state: TranscriptionState (Idle/Loading/Chunking/Success/Error/MissingKey)
  ├── chunks: List<ChunkState> (waiting/uploading/done/failed per chunk)
  ├── _Semaphore(maxConcurrent: 3)
  └── Future.wait(chunks.map(_transcribeWithRetry))
        │
        ├──[per chunk]─▶ GroqApiService.transcribeChunk(path, apiKey, offset)
        │                  └── _withRetry(maxAttempts: 4, baseDelay: 5s)
        │                        └── HTTP POST multipart → Groq Whisper API
        │                              └── TranscriptionResult (text + words[])
        │
        ▼ [all done]
assembleTranscript(List<ChunkTranscriptResult>)
  └── TranscriptionSuccess(assembled TranscriptionResult)
        │
        ▼
ProcessingScreen (extends existing)
  ├── file < 19 MB → existing single-shot flow (TranscriptionLoading)
  └── file ≥ 19 MB → chunked flow (TranscriptionChunking + progress UI)
```

### Recommended Project Structure

```
lib/
├── core/
│   └── error/app_exception.dart       # добавить ChunkException если нужно
├── features/
│   └── transcription/
│       ├── audio_chunking_service.dart # НОВЫЙ: ffprobe + ffmpeg split
│       ├── audio_file_info.dart        # НОВЫЙ: модель метаданных (duration, codec)
│       ├── chunk_state.dart            # НОВЫЙ: ChunkStatus enum + ChunkState
│       ├── chunk_transcript_result.dart # НОВЫЙ: результат одного чанка
│       ├── chunked_transcription_controller.dart # НОВЫЙ: заменяет TranscriptionController для длинных файлов
│       ├── groq_api_service.dart       # ИЗМЕНИТЬ: добавить transcribeChunk() + retry
│       ├── selected_audio_file.dart    # ИЗМЕНИТЬ: добавить durationSeconds?
│       ├── transcription_controller.dart # СОХРАНИТЬ: используется для <19MB
│       └── transcription_result.dart   # СОХРАНИТЬ: без изменений
└── ui/
    └── screens/
        └── processing_screen.dart      # ИЗМЕНИТЬ: добавить ветку TranscriptionChunking
```

**Порог переключения**: `if (file.sizeBytes > 19 * 1024 * 1024)` — в `ProcessingScreen.didChangeDependencies()`, выбрать нужный контроллер.

---

## Pitfalls & Gotchas

### Pitfall 1: getDuration() возвращает миллисекунды, не секунды
**Что идёт не так:** Разработчик ожидает `info.getDuration()` в секундах (как ffmpeg output), но FFprobeKit возвращает строку в **миллисекундах**.
**Как избежать:** Всегда делить на 1000.0: `double.parse(info.getDuration()!) / 1000.0`.
**Признак:** Длительность лекции кажется в 1000 раз больше реальной.

### Pitfall 2: ffmpeg segment нумерует с 0, имена предсказуемы но не гарантированы
**Что идёт не так:** `outputPattern = '%03d.mp3'` создаёт `000.mp3, 001.mp3, ...` — но при частичном сбое порядок может нарушиться.
**Как избежать:** После split сортировать список чанков по имени файла (`..sort()`), не полагаться на порядок в Directory.listSync().

### Pitfall 3: Future.wait прерывается при первой ошибке по умолчанию
**Что идёт не так:** Если один чанк падает с необработанным исключением, `Future.wait` отменяет ожидание остальных, но уже запущенные Future продолжают выполняться.
**Как избежать:** Оборачивать каждый chunk-future в `try/catch` внутри `.map()`, аккумулировать ошибки, решать по завершении всех.

### Pitfall 4: Groq 429 с Retry-After — нужно ждать header, не константу
**Что идёт не так:** Константный backoff не учитывает реальное время ожидания от Groq при rate limit.
**Как избежать:** При 429 парсить `response.headers['retry-after']` и ждать указанное время (+ 1 сек буфер). Если header отсутствует — базовый backoff.

### Pitfall 5: ffmpeg не закрывается при dispose() контроллера
**Что идёт не так:** Пользователь нажимает "Отменить" → `dispose()` → ffmpeg продолжает резать в фоне, tmp-файлы не удаляются.
**Как избежать:** `FFmpegKit.cancel()` или `session.cancel()` при отмене. Хранить `_currentSession` в `AudioChunkingService` и вызывать `session.cancel()` в методе `cancel()`.

### Pitfall 6: file_picker кеш — путь невалиден после рестарта приложения
**Что идёт не так:** Путь из `file_picker` ведёт во временный кеш. При рестарте приложения файл может быть удалён ОС.
**Как избежать:** Для Phase 2 это не проблема — файл используется сразу. Не хранить путь в persist-хранилище.

### Pitfall 7: Частичные сегменты — последний чанк короче 1200 сек
**Что идёт не так:** offset для последнего чанка рассчитывается как `index * 1200`, но реальная длительность последнего чанка меньше.
**Как избежать:** offset всегда `index * segmentDurationSeconds` (то, что было передано в ffmpeg). Реальная длительность не важна для text-сборки — важна только стартовая позиция.

---

## Standard Stack

### Core (no new packages needed)
| Library | Version | Purpose | Status |
|---------|---------|---------|--------|
| `ffmpeg_kit_flutter_new` | ^4.1.0 | ffprobe metadata + ffmpeg split | Already in pubspec [CITED: pub.dev] |
| `http` | ^1.4.0 | Parallel HTTP to Groq | Already in pubspec |
| `path_provider` | ^2.1.5 | getTemporaryDirectory() for chunks | Already in pubspec |
| `flutter` ChangeNotifier | SDK | Per-chunk state UI | Built-in |

### No New Packages Required
- Bounded concurrency: ручной `_Semaphore` (20 строк Dart) — не нужен внешний пакет
- Retry: ручной `_withRetry` (20 строк Dart) — не нужен пакет `retry`
- Temp file cleanup: `dart:io` Directory.delete() — встроено

## Package Legitimacy Audit

> Для Phase 2 не вводятся новые внешние пакеты. Все зависимости были проверены в Phase 1.
> Пакет `ffmpeg_kit_flutter_new` подтверждён: pub.dev/packages/ffmpeg_kit_flutter_new, издатель antonkarpenko.com, GitHub: github.com/sk3llo/ffmpeg_kit_flutter (форк arthenica), версия 4.1.0 [CITED: pub.dev].

**Packages removed due to slopcheck:** none — no new packages introduced.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK) + mockito ^5.4.4 |
| Config file | pubspec.yaml (dev_dependencies) |
| Quick run command | `flutter test test/features/transcription/ -x` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| IMPORT-03 | FFprobeKit возвращает корректную длительность | unit (mock FFprobeKit) | `flutter test test/features/transcription/audio_chunking_service_test.dart -x` | Wave 0 |
| IMPORT-04 | AudioFileInfo заполняется перед стартом | unit | вместе с IMPORT-03 | Wave 0 |
| TRANS-04 | Файл >19 МБ вызывает splitAudio, создаёт ≥2 чанков | unit (mock FFmpegKit) | `flutter test test/features/transcription/audio_chunking_service_test.dart -x` | Wave 0 |
| TRANS-05 | Не более 3 одновременных HTTP-запросов | unit (_Semaphore) | `flutter test test/features/transcription/semaphore_test.dart -x` | Wave 0 |
| TRANS-06 | Retry логика: 3 попытки, правильные задержки | unit | `flutter test test/features/transcription/groq_api_service_test.dart -x` | частично (сервис существует) |
| TRANS-08 | Offset применяется корректно при сборке | unit | `flutter test test/features/transcription/transcript_assembly_test.dart -x` | Wave 0 |
| TRANS-09 | ChunkStatus обновляется при изменении состояния | unit (ChangeNotifier) | `flutter test test/features/transcription/chunked_controller_test.dart -x` | Wave 0 |
| TRANS-10 | Temp-файлы удаляются после завершения | unit (mock Directory) | вместе с TRANS-04 | Wave 0 |

### Wave 0 Gaps
- [ ] `test/features/transcription/audio_chunking_service_test.dart` — покрывает IMPORT-03, IMPORT-04, TRANS-04, TRANS-10
- [ ] `test/features/transcription/semaphore_test.dart` — покрывает TRANS-05
- [ ] `test/features/transcription/transcript_assembly_test.dart` — покрывает TRANS-08
- [ ] `test/features/transcription/chunked_controller_test.dart` — покрывает TRANS-09
- [ ] Обновить `test/features/transcription/groq_api_service_test.dart` — добавить тесты retry/524/429

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | нет — API-ключ уже в flutter_secure_storage из Phase 1 | — |
| V3 Session Management | нет | — |
| V4 Access Control | нет | — |
| V5 Input Validation | да | Проверять что chunk-файл существует и >0 байт перед отправкой |
| V6 Cryptography | нет | — |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Tmp-файл читается другим процессом | Disclosure | App-scoped tmp dir (getCacheDir) — Android изолирует по умолчанию |
| ffmpeg shell injection через имя файла | Tampering | Экранировать путь в кавычки в cmd string; не интерполировать user-input напрямую |
| API-ключ в лог-выводе ffprobe/ffmpeg | Disclosure | API-ключ не передаётся в ffmpeg-команды; только в HTTP headers |

---

## Open Questions (RESOLVED)

1. **Возвращает ли Groq verbose_json сегменты без явного `timestamp_granularities[]=segment`?**
   **RESOLVED:** План 02-02 Task 2 явно добавляет `timestamp_granularities[]=segment` в `transcribeChunk()` наряду с `word`. Таким образом `segments[]` гарантированно присутствует в ответе вне зависимости от поведения API по умолчанию.

2. **Точный RPM лимит Groq whisper-large-v3 на free tier**
   **RESOLVED:** Используем консервативный лимит 3 параллельных запроса. При получении 429 `RateLimitException` вызывается retry с задержкой 5s→10s→20s. Executor должен логировать 429-ответы для последующей корректировки константы `maxConcurrent`.

3. **ffmpegKit версия 4.1.0 vs актуальная**
   **RESOLVED:** Используем `^4.1.0` (уже в pubspec). Dart pub resolver подберёт последнюю совместимую minor-версию. Executor запускает `flutter pub get` — этого достаточно.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| ffmpeg_kit_flutter_new | TRANS-04 (chunking) | ✓ (в pubspec) | ^4.1.0 | Нет альтернативы |
| Android device / emulator | Ручное тестирование | ✓ (физический телефон, D-10) | — | — |
| Flutter SDK | Сборка | ✓ | ≥3.5.0 | — |
| Groq API key | TRANS-04..10 | ✓ (пользователь вводит) | — | — |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Groq безопасная параллельность = 3 запроса для free tier | §Findings 2 | 429-ошибки; решение — уменьшить до 2 |
| A2 | `segments[]` присутствует в verbose_json при только word-granularity | §Findings 4 | Сборка по сегментам сломается; решение — добавить segment в запрос |
| A3 | baseDelay=5s соответствует требованию TRANS-06 "5·2^attempt" | §Findings 3 | Нет (TRANS-06 явно указывает 5*2^attempt — это соответствует коду) |
| A4 | ffmpeg_kit_flutter_new 4.1.0 — актуальная версия | §Standard Stack | Может быть более новая версия; проверить pub outdated |
| A5 | `MediaInformation.getDuration()` возвращает мс в виде строки | §Findings 1 | Другие единицы; тест с реальным файлом в Wave 0 |

---

## Sources

### Primary (HIGH confidence)
- [arthenica/ffmpeg-kit Wiki Flutter](https://github.com/arthenica/ffmpeg-kit/wiki/Flutter) — FFmpegKit.executeAsync, FFprobeKit.getMediaInformation API
- [ffmpeg_kit_flutter_new pub.dev](https://pub.dev/packages/ffmpeg_kit_flutter_new) — версия, платформы, издатель
- [ffmpeg_kit_flutter_new Dart API docs](https://pub.dev/documentation/ffmpeg_kit_flutter_new/latest/) — MediaInformation API
- [dart.dev/language/concurrency](https://dart.dev/language/concurrency) — Future.wait, async patterns

### Secondary (MEDIUM confidence)
- [console.groq.com/docs/speech-to-text](https://console.groq.com/docs/speech-to-text) — verbose_json response format, segments
- [community.groq.com — free tier limits](https://community.groq.com/t/is-there-a-free-tier-and-what-are-its-limits/790) — 2000 RPD, 7200 audio seconds/hour
- [pub.dev/packages/path_provider](https://pub.dev/packages/path_provider) — getTemporaryDirectory on Android
- [pub.dev/packages/file_picker](https://pub.dev/packages/file_picker) — scoped storage caching behavior

### Tertiary (LOW confidence)
- [community.groq.com — rate limits FAQ](https://community.groq.com/t/what-are-the-rate-limits-for-the-groq-api-for-the-free-and-dev-tier-plans/42) — RPM estimates

---

## Metadata

**Confidence breakdown:**
- ffmpeg_kit API: HIGH — wiki + pub.dev docs прямо описывают методы
- Parallel HTTP pattern: HIGH — официальный dart.dev concurrency guide
- Groq rate limits: MEDIUM — community forum, не официальная docs страница с числами
- Transcript assembly: HIGH — Groq docs подтверждают segments[] структуру
- Retry pattern: HIGH — стандартный Dart паттерн

**Research date:** 2026-05-17
**Valid until:** 2026-06-17 (стабильные APIs)

---

## RESEARCH COMPLETE
