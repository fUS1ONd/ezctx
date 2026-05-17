# Phase 4: Multi-Key Pool & Rate-Limit UI - Context

**Gathered:** 2026-05-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Пользователь добавляет несколько Groq API-ключей и получает автоматическую ротацию без вмешательства: пул берёт следующий живой ключ при 429, ждёт разблокировки если все заблокированы, а экран настроек в реальном времени показывает статус каждого ключа (активен / заблокирован до HH:MM:SS).

**Что входит:** `GroqKeyPool` сервис, wire-up в оба контроллера (chunked + single-shot), парсинг заголовков `retry-after`/`x-ratelimit-reset-*`, per-key статус в `ApiKeysScreen`.

**Что не входит:** выбор модели/языка, SRT/share, история, onboarding.

</domain>

<decisions>
## Implementation Decisions

### Архитектура GroqKeyPool

- **D-01:** `GroqKeyPool extends ChangeNotifier` — живёт синглтоном, создаётся в `main.dart` и передаётся как зависимость. UI слушает через `ListenableBuilder` — реактивно, без таймера-поллинга.
- **D-02:** Пул хранит состояние только в памяти (`blockedUntil: DateTime`). Timeout короткий (60–300с) — персист через рестарт не нужен.
- **D-03:** Интерфейс пула: `acquireKey()` (async, ждёт живой ключ), `reportRateLimited(key, seconds)` (блокирует ключ), `getStatuses()` → `List<KeyStatus>` (для UI).

### Ротация при 429 (blackbox-пул)

- **D-04:** Контроллер передаёт ответственность пулу: вызывает `pool.reportRateLimited(key, e.retryAfterSeconds)`, затем снова `pool.acquireKey()` и повторяет чанк. Логика "какой ключ следующий" остаётся внутри пула — контроллер не знает о round-robin.
- **D-05:** `pool.acquireKey()` — async, блокирует до появления живого ключа. Если все ключи заблокированы — ждёт разблокировки ближайшего и затем возвращает его. Таймаут ожидания: 10 минут (после чего кидает `AllKeysBlockedException`).
- **D-06:** `RateLimitException` получает поле `retryAfterSeconds: int` (default 60). `GroqApiService` парсит заголовки в порядке: `retry-after` → `x-ratelimit-reset-requests` (берём min из двух) → fallback 60с.
- **D-07:** Рекурсия `_processChunk` заменяется на while-loop с лимитом попыток (max 10), чтобы избежать stack overflow при длинных блокировках.

### UI статуса ключей

- **D-08:** На `ApiKeysScreen` каждый ключ показывает только статус: зелёный индикатор "Активен" или красный "До HH:MM:SS". Никакой квоты в v1 — упрощает UI и убирает зависимость от наличия заголовков.
- **D-09:** Обратный отсчёт "До HH:MM:SS" реализуется локальным 1s-тикером (`Timer.periodic`) в виджете ключа — пул не нотифицирует каждую секунду, только при смене статуса (заблокирован/разблокирован).
- **D-10:** `ApiKeysScreen` подписывается на `GroqKeyPool` через `ListenableBuilder` — ребилд при изменении статуса без постоянного поллинга.

### Оба контроллера через пул

- **D-11:** И `ChunkedTranscriptionController`, и `TranscriptionController` (single-shot) берут ключ через `pool.acquireKey()`. Single-shot тоже ротирует при 429 — иначе короткие файлы игнорируют rate limit.
- **D-12:** Семафор `_Semaphore(maxConcurrent)` остаётся, но `maxConcurrent` берётся динамически: `min(pool.aliveKeyCount, kMaxConcurrentChunks)`. Константа `kMaxConcurrentChunks = 5`.

### Claude's Discretion

- Структура `KeyStatus` (value object или record) — на усмотрение реализации.
- Конкретный алгоритм round-robin в пуле (cyclic index vs shuffle) — на усмотрение.
- Нужен ли новый `ChunkState` ("ожидание ключа") — реализация может добавить `ChunkWaitingForKey` если это улучшает UX обратной связи.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Требования
- `.planning/REQUIREMENTS.md` §Settings & Keys (KEYS-01–05) — требования к ключам
- `.planning/REQUIREMENTS.md` §Transcription Engine (TRANS-01, TRANS-02) — требования к пулу и заголовкам

### Roadmap и контекст фазы
- `.planning/ROADMAP.md` §Phase 4 — goal, success criteria, зависимости

### Существующий код (обязательно прочитать перед планированием)
- `lib/features/transcription/groq_api_service.dart` — текущий HTTP-клиент, нужно добавить парсинг заголовков
- `lib/features/transcription/chunked_transcription_controller.dart` — wire-up пула сюда; текущий `keys.first.raw` заменить на `pool.acquireKey()`
- `lib/features/transcription/transcription_controller.dart` — single-shot, аналогичный wire-up
- `lib/features/settings/api_key_repository.dart` — CRUD ключей, источник данных для пула
- `lib/ui/screens/api_keys_screen.dart` — добавить per-key статус, подписку на пул
- `lib/core/error/app_exception.dart` — добавить `retryAfterSeconds` в `RateLimitException`
- `lib/features/transcription/chunk_state.dart` — возможно, добавить `ChunkWaitingForKey`
- `lib/core/constants/app_constants.dart` — добавить `kMaxConcurrentChunks`

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `_Semaphore` в `chunked_transcription_controller.dart` — паттерн Completer-очереди; `GroqKeyPool.acquireKey()` реализует аналогичный паттерн для ожидания ключа.
- `ApiKeyRepository.listKeys()` — источник сырых ключей для инициализации пула при старте.
- `GlassTile` + `GlassCard` виджеты — паттерн UI-карточек; статус-карточки ключей следуют тому же дизайну.

### Established Patterns
- `ChangeNotifier` + `notifyListeners()` — уже используется в `ChunkedTranscriptionController`; `GroqKeyPool` следует той же конвенции.
- `sealed class ChunkState` — паттерн состояний; `KeyStatus` будет аналогичным sealed class или value object.
- Инъекция зависимостей через конструктор (не глобальные синглтоны в коде) — пул передаётся в контроллеры явно.

### Integration Points
- `ChunkedTranscriptionController.start()` → `pool.acquireKey()` перед каждым `_processChunk`
- `GroqApiService.transcribeChunk()` → ответственность за парсинг заголовков 429
- `main.dart` → создание синглтона `GroqKeyPool` и предоставление его обоим контроллерам и `ApiKeysScreen`
- `ApiKeysScreen` → `ListenableBuilder(listenable: pool, builder: ...)` для реактивного обновления статусов

### Уже реализовано (не дублировать)
- KEYS-03 (удалить ключ) — `_confirmDelete` в `api_keys_screen.dart` уже работает.
- KEYS-04 (ссылка на console.groq.com) — `launchUrl` уже есть в `api_keys_screen.dart`.

</code_context>

<specifics>
## Specific Ideas

- `pool.acquireKey()` блокирует (через Completer) пока нет живого ключа — аналог `_Semaphore.run()` из chunked controller.
- Паттерн ротации: при `reportRateLimited` пул помечает ключ и вызывает `notifyListeners()` — UI обновляется мгновенно.
- Для отсчёта "до HH:MM:SS" в `ApiKeysScreen`: `Timer.periodic(1s)` в `State.initState`, читает `pool.getStatuses()` для форматирования, `setState()` только если отображаемое значение изменилось.

</specifics>

<deferred>
## Deferred Ideas

- **Показ квоты (remaining-requests / remaining-tokens)** — обсуждалось, отложено. Заголовки будем парсить и хранить в пуле, но в UI v1 не отображаем. Phase 8 ("Error Handling & Onboarding Polish") может добавить.
- **Персистентность статуса пула через рестарт** — таймауты короткие, не нужно для v1.
- **`ProcessingScreen` с per-key статусом** — во время транскрибации видно какой ключ используется для какого чанка. Красиво, но не в MVP.

</deferred>

---

*Phase: 4-Multi-Key Pool & Rate-Limit UI*
*Context gathered: 2026-05-17*
