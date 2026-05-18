# Roadmap: ezctx (Android v1 MVP)

**Created:** 2026-05-16
**Mode:** Vertical MVP — каждая фаза доставляет end-to-end слайс пользовательской ценности
**Granularity:** standard
**Target artifact:** Android debug APK, полностью покрывающий core value «загрузил лекцию → получил txt в буфере»
**Coverage:** 36/36 v1 requirements mapped ✓

## Phases

- [ ] **Phase 1: Walking Skeleton (Short Audio → Clipboard)** — Минимальный end-to-end слайс: пользователь импортирует короткий (<19 MB) аудиофайл, получает текст на экране и копирует в буфер.
- [ ] **Phase 2: Real Lectures (Chunking & Progress)** — Большие файлы (>19 MB) режутся ffmpeg-ом, отправляются параллельно, пользователь видит прогресс.
- [ ] **Phase 3: Audio Normalization (Pre-Transcription)** — Любой аудиоформат конвертируется в 32 kbps / 16 kHz / Mono mp3 перед чанкованием; isChunked определяется по длительности нормализованного файла.
- [x] **Phase 4: Multi-Key Pool & Rate-Limit UI** — Пул из нескольких Groq-ключей с round-robin, авто-блокировкой и видимым в UI статусом/квотой.
- [ ] **Phase 5: Model & Language Controls** — Переключатель large-v3 / turbo и селектор языка распознавания.
- [ ] **Phase 6: Output Formats & Sharing** — SRT с таймкодами + share intent в Telegram/GPT/заметки.
- [ ] **Phase 7: History** — Локальный список ранее расшифрованных лекций с возможностью повторного открытия и удаления.
- [ ] **Phase 8: Error Handling & Onboarding Polish** — Onboarding без ключей, понятные сетевые ошибки с retry, ожидание разблокировки ключей с обратным отсчётом.

## Phase Details

### Phase 1: Walking Skeleton (Short Audio → Clipboard)

**Goal:** Пользователь устанавливает APK, добавляет один Groq-ключ, выбирает короткий аудиофайл (<19 MB) и получает расшифрованный текст с кнопкой «Скопировать».
**Mode:** mvp
**Depends on:** Nothing (first phase)
**Requirements:** FOUND-01, FOUND-02, FOUND-03, KEYS-01, KEYS-02, IMPORT-01, IMPORT-02, TRANS-03, TRANS-07, OUT-02, OUT-03, OUT-05
**Success Criteria** (what must be TRUE):

  1. Debug APK устанавливается на Android-устройство и запускается без падений.
  2. Пользователь может ввести один Groq API-ключ в настройках; ключ сохраняется в `flutter_secure_storage` и переживает перезапуск приложения.
  3. Пользователь может выбрать `.mp3`/`.m4a`/`.wav` файл < 19 MB через системный file_picker; файлы с неподдерживаемым расширением отклоняются с понятным сообщением.
  4. После нажатия «Транскрибировать» приложение отправляет файл одним запросом в Groq Whisper (`verbose_json`, `large-v3`) и показывает расшифрованный текст на экране результата.
  5. Кнопка «Скопировать txt» помещает полный текст в системный буфер обмена; вставка в стороннее приложение (например, Telegram) даёт ту же строку.

**Plans:** 5 plans
Plans:
**Wave 1**

- [ ] 01-01-PLAN.md — Walking Skeleton: Flutter init + design tokens + 5 экранов-навигация + CI + skeleton secure_storage read/write

**Wave 2** *(blocked on Wave 1 completion)*

- [ ] 01-02-PLAN.md — API Keys: ApiKeyRepository + полноценный ApiKeysScreen (add/list/remove + маскирование) + счётчик в SettingsScreen
- [ ] 01-03-PLAN.md — File Import: FileValidator + FilePickerService + HomeScreen preview + активация кнопки

**Wave 3** *(blocked on Wave 2 completion)*

- [ ] 01-04-PLAN.md — Groq Transcription: GroqApiService + TranscriptionController + ProcessingScreen (pipeline, shimmer, errors)

**Wave 4** *(blocked on Wave 3 completion)*

- [ ] 01-05-PLAN.md — Result Screen: Clipboard + SelectableText + transcript.txt save + E2E чекпоинт на устройстве

**UI hint:** yes

### Phase 2: Real Lectures (Chunking & Progress)

**Goal:** Пользователь может транскрибировать реальные лекционные записи (часовые файлы, сотни мегабайт), видя прогресс по чанкам.
**Mode:** mvp
**Depends on:** Phase 1
**Requirements:** IMPORT-03, IMPORT-04, TRANS-04, TRANS-05, TRANS-06, TRANS-08, TRANS-09, TRANS-10
**Success Criteria** (what must be TRUE):

  1. После выбора файла пользователь видит его метаданные (имя, длительность, размер) до запуска — длительность приходит из ffprobe.
  2. Файл > 19 MB автоматически режется ffmpeg-ом на сегменты ≤ 19 MB (базово 1200 сек, mp3 128k); пользователь не делает никаких ручных действий.
  3. Чанки отправляются параллельно; на экране виден общий процент прогресса и статус по каждому чанку (ожидает / отправляется / готов / ретрай).
  4. Транзиентные сетевые ошибки и 524 от Groq автоматически ретраятся с экспоненциальной задержкой без потери чанка.
  5. По завершении расшифровка собирается из всех чанков с корректными таймкодами (offset = `index * chunk_duration`); промежуточные mp3-чанки удаляются из tmp.

**Plans:** 4 plans
Plans:

**Wave 1** *(параллельно)*

- [ ] 02-01-PLAN.md — AudioChunkingService: ffprobe-метаданные + ffmpeg-разбивка на чанки
- [ ] 02-02-PLAN.md — ChunkedTranscriptionController: параллельность + retry + сборка таймкодов

**Wave 2** *(заблокировано до Wave 1)*

- [ ] 02-03-PLAN.md — UI: карточка метаданных + ChunkedProcessingScreen с прогрессом по чанкам
- [ ] 02-04-PLAN.md — Интеграция: маршрутизация + ResultScreen таймкоды + e2e тест

**UI hint:** yes

### Phase 3: Audio Normalization (Pre-Transcription)

**Goal:** Любой аудиоформат (mp3, m4a, ogg, wav, flac, webm, mp4, mpeg, mpga) нормализуется в 32 kbps / 16 kHz / Mono mp3 перед чанкованием; isChunked определяется по длительности нормализованного файла; UI показывает «Подготовка аудио…» во время конвертации.
**Mode:** mvp
**Depends on:** Phase 2
**Requirements:** TRANS-04, TRANS-05

**Success Criteria** (what must be TRUE):

  1. Любой файл из поддерживаемых форматов (mp3/m4a/ogg/wav/flac/webm/mp4/mpeg/mpga) успешно конвертируется в 32 kbps / 16 kHz / Mono mp3 через ffmpeg без ошибок.
  2. isChunked вычисляется на основе **длительности** нормализованного файла (порог ≈ 80 мин = ~19 MB при 32 kbps), а не по исходному размеру файла.
  3. Нормализация выполняется **всегда** (и для коротких, и для длинных файлов) как первый шаг pipeline до определения пути (single-shot / chunked).
  4. UI показывает индикатор «Подготовка аудио…» пока идёт ffmpeg-конвертация; после завершения переходит к прогрессу чанков (или single-shot).
  5. 35 MB OGG-лекция длительностью < 80 мин успешно разбивается на корректные чанки и полностью расшифровывается через Groq.

**Plans:** 3 plans

**UI hint:** yes

### Phase 4: Multi-Key Pool & Rate-Limit UI

**Goal:** Пользователь добавляет несколько Groq-ключей и видит, какие из них активны / заблокированы / сколько квоты осталось; пул сам ротирует ключи и переживает 429.
**Mode:** mvp
**Depends on:** Phase 3
**Requirements:** KEYS-03, KEYS-04, KEYS-05, TRANS-01, TRANS-02
**Success Criteria** (what must be TRUE):

  1. На экране настроек пользователь может добавить N ключей, удалить любой, и открыть кликабельную ссылку на `https://console.groq.com/keys`.
  2. При запуске расшифровки чанки распределяются round-robin между всеми живыми ключами (видно в логах/статусе по чанкам).
  3. При получении 429/503 от Groq ключ автоматически блокируется на время из заголовков `retry-after` / `x-ratelimit-reset-*` (фоллбэк 60 сек), а другие чанки продолжают идти через оставшиеся ключи.
  4. Для каждого ключа в UI видны: статус (активен / заблокирован до HH:MM:SS) и остаток квоты, если он есть в заголовках Groq; индикатор обновляется в реальном времени.
  5. Часовая лекция, которая упёрлась бы в лимит одного ключа, успешно расшифровывается на двух ключах без вмешательства пользователя.

**Plans:** 3 plans
Plans:

**Wave 1** *(параллельно)*

- [ ] 04-01-PLAN.md — GroqKeyPool core: test stubs + AllKeysBlockedException + RateLimitException.retryAfterSeconds + GroqKeyPool ChangeNotifier + парсинг заголовков в GroqApiService

**Wave 2** *(заблокировано до Wave 1)*

- [ ] 04-02-PLAN.md — Controller migration: ChunkedTranscriptionController + TranscriptionController на pool.acquireKey() + wire-up в main.dart

**Wave 3** *(заблокировано до Wave 2)*

- [ ] 04-03-PLAN.md — UI: KeyStatusTile + ApiKeysScreen ListenableBuilder + pool sync + checkpoint на устройстве

**UI hint:** yes

### Phase 5: Model & Language Controls

**Goal:** Пользователь может выбрать между качеством (`large-v3`) и скоростью (`large-v3-turbo`) и явно задать язык распознавания для повышения точности на русском.
**Mode:** mvp
**Depends on:** Phase 4
**Requirements:** OPTS-01, OPTS-02, OPTS-03
**Success Criteria** (what must be TRUE):

  1. На экране запуска транскрибации виден переключатель модели `large-v3` (по умолчанию) / `large-v3-turbo`; выбор сохраняется между сессиями.
  2. Виден селектор языка со списком «Авто / ru / en / +основные»; дефолт — «Авто».
  3. При «Авто» в multipart-запросе к Groq поле `language` отсутствует; при явном выборе — передаётся корректный ISO-код (проверяется по логам/инспектору запроса).
  4. Русскоязычная запись, расшифрованная с `language=ru` и `large-v3`, имеет заметно меньше ошибок распознавания, чем та же запись с `large-v3-turbo` и «Авто» (ручная проверка одной и той же лекции).

**Plans:** TBD
**UI hint:** yes

### Phase 6: Output Formats & Sharing

**Goal:** Кроме сырого txt пользователь получает субтитровый файл `transcript.srt` и может отправить расшифровку в Telegram/GPT/заметки одним тапом.
**Mode:** mvp
**Depends on:** Phase 5
**Requirements:** OUT-01, OUT-04
**Success Criteria** (what must be TRUE):

  1. По завершении транскрибации в постоянном хранилище приложения появляется пара файлов `transcript.txt` + `transcript.srt`; SRT валиден и открывается любым плеером с таймкодами.
  2. На экране результата есть кнопка «Поделиться», открывающая системный share-sheet Android с готовым текстом.
  3. Через share-sheet пользователь может отправить расшифровку в Telegram, в системные «Заметки» и в приложение ChatGPT/Claude (если установлено) — текст приходит без обрезаний.
  4. Кнопка «Скопировать» и share-кнопка доступны одновременно; пользователь может вернуться и нажать любую из них без повторной расшифровки.

**Plans:** TBD
**UI hint:** yes

### Phase 7: History

**Goal:** Пользователь возвращается к ранее расшифрованным лекциям из главного экрана без повторного прогона через Groq.
**Mode:** mvp
**Depends on:** Phase 6
**Requirements:** HIST-01, HIST-02, HIST-03, HIST-04
**Success Criteria** (what must be TRUE):

  1. Каждая успешная транскрибация автоматически сохраняется в локальной истории с именем файла, датой, длительностью и путями к txt/srt.
  2. Главный экран при старте показывает список ранее расшифрованных лекций, отсортированных по дате (новые сверху).
  3. Тап по записи открывает экран результата с тем же txt/srt; кнопки «Скопировать» и «Поделиться» работают как сразу после транскрибации.
  4. Пользователь может удалить запись свайпом или из меню; после удаления файлы txt/srt исчезают из хранилища, а запись пропадает из списка.

**Plans:** TBD
**UI hint:** yes

### Phase 8: Error Handling & Onboarding Polish

**Goal:** Приложение ведёт нового пользователя за руку и понятно объясняет любую ошибку — APK готов к раздаче через Firebase App Distribution.
**Mode:** mvp
**Depends on:** Phase 7
**Requirements:** ERR-01, ERR-02, ERR-03
**Success Criteria** (what must be TRUE):

  1. При первом запуске без сохранённых ключей пользователь попадает на onboarding-экран с инструкцией и кнопкой «Добавить ключ», ведущей в настройки.
  2. При обрыве сети или DNS-ошибке пользователь видит человекочитаемое сообщение (не stack trace) и кнопку «Повторить», которая возобновляет тот же таск с того же чанка.
  3. Когда все ключи заблокированы, на экране прогресса виден обратный отсчёт до ближайшей разблокировки и приложение само возобновляет работу по истечении таймера, без перезапуска.
  4. Сборка release-APK устанавливается на чистое устройство и проходит весь сценарий «добавить ключ → импортировать лекцию → получить txt в буфере» без ошибок и фризов.

**Plans:** TBD
**UI hint:** yes

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Walking Skeleton (Short Audio → Clipboard) | 5/5 | Complete | 2026-05-17 |
| 2. Real Lectures (Chunking & Progress) | 4/4 | Complete | 2026-05-17 |
| 3. Audio Normalization (Pre-Transcription) | 0/? | Not started | - |
| 4. Multi-Key Pool & Rate-Limit UI | 0/3 | Planned | - |
| 5. Model & Language Controls | 0/? | Not started | - |
| 6. Output Formats & Sharing | 0/? | Not started | - |
| 7. History | 0/? | Not started | - |
| 8. Error Handling & Onboarding Polish | 0/? | Not started | - |

## Rebalancing Notes

Исходный mapping в REQUIREMENTS.md (Phase 1 = только FOUND) был **horizontal slice** — пользователь после Phase 1 не получал никакой ценности. Перебалансировано в **vertical MVP**:

- **Phase 1** получил минимально необходимые KEYS (01, 02), IMPORT (01, 02), TRANS (03 single-shot, 07 verbose_json) и OUT (02 txt, 03 copy, 05 display) — чтобы уже после первой фазы был работающий APK, расшифровывающий короткое аудио.
- **Phase 2** взял на себя «реальные лекции» — чанкование, параллельность, прогресс. Без Phase 1 пользы нет, но и Phase 1 без Phase 2 уже полезна для коротких заметок.
- **Phase 3** получил остаток KEYS (03, 04, 05) и TRANS-01/02, потому что multi-key pool имеет смысл только когда уже есть нагрузка из Phase 2.
- Остальные фазы (4–7) сохранили исходное намерение, но `OUT-04 share` поднят в Phase 5 (где он логичен) — изначально был там же.

Итог: 36/36 требований смаплены, каждая фаза добавляет user-visible value, ни одна не «инфраструктурная прослойка».

---
*Roadmap initialized: 2026-05-16*
