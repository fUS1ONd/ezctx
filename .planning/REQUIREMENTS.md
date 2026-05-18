# Requirements: ezctx

**Defined:** 2026-05-16
**Core Value:** Пользователь записал лекцию на телефон → импортировал в ezctx → через минуты получил готовый txt в буфере / share intent, не перегоняя файл на компьютер.

## v1 Requirements

Требования к первому Android-релизу. Каждое маппится на фазу в ROADMAP.md.

### Foundation (FOUND)

- [ ] **FOUND-01**: Flutter-проект инициализирован, собирается под Android (debug APK) на Windows+WSL
- [ ] **FOUND-02**: Базовая структура папок (`lib/core/`, `lib/features/`, `lib/ui/`) и зависимости подключены (http, file_picker, flutter_secure_storage, ffmpeg_kit_flutter, path_provider)
- [ ] **FOUND-03**: Дизайн-система перенесена из React-прототипа (цвета, шрифты, базовые компоненты)

### Settings & Keys (KEYS)

- [ ] **KEYS-01**: Пользователь может добавить один или несколько Groq API-ключей через экран настроек
- [ ] **KEYS-02**: Ключи сохраняются в `flutter_secure_storage` (не в обычном prefs, не в коде сборки)
- [ ] **KEYS-03**: Пользователь может удалить ключ из списка
- [ ] **KEYS-04**: На экране настроек есть кликабельная ссылка на `https://console.groq.com/keys`
- [ ] **KEYS-05**: Для каждого ключа отображается статус (активен / заблокирован до HH:MM:SS) и доступная квота (если есть из заголовков Groq)

### Audio Import (IMPORT)

- [ ] **IMPORT-01**: Пользователь может выбрать локальный аудиофайл через системный file_picker
- [ ] **IMPORT-02**: Расширение файла валидируется по whitelist Groq (flac/mp3/mp4/mpeg/mpga/m4a/ogg/wav/webm); при отклонении — понятная ошибка
- [ ] **IMPORT-03**: ffprobe (через `ffmpeg_kit_flutter`) определяет длительность, битрейт, кодек до начала работы
- [ ] **IMPORT-04**: Пользователь видит метаданные выбранного файла (имя, длительность, размер) перед запуском транскрибации

### Transcription Engine (TRANS)

- [ ] **TRANS-01**: Порт `GroqKeyPool` из LectureLog на Dart: round-robin выдача ключей, учёт RPM, блокировка ключа при 429/503
- [ ] **TRANS-02**: Длительность блокировки ключа берётся из заголовков `retry-after` / `x-ratelimit-reset-*` (фоллбэк 60 сек)
- [ ] **TRANS-03**: Файл < 19 MB и в whitelist отправляется одним запросом, без сегментации
- [ ] **TRANS-04**: Файл > 19 MB режется ffmpeg-ом (`-f segment`, базово 1200 сек, mp3 128k); при необходимости — downmix в моно и 16 kHz
- [ ] **TRANS-05**: Чанки отправляются параллельно через семафор `min(len(alive_keys), N)`
- [ ] **TRANS-06**: Ретраи с экспоненциальной задержкой (5·2^attempt) на транзиентных ошибках; 524 — повтор того же чанка
- [ ] **TRANS-07**: Запрос Groq использует `response_format=verbose_json` и `timestamp_granularities=[word]`
- [ ] **TRANS-08**: Слова из всех чанков склеиваются с учётом offset (`index * chunk_duration`)
- [ ] **TRANS-09**: Пользователь видит прогресс транскрибации (общий процент + статус по чанкам)
- [ ] **TRANS-10**: Промежуточные чанки удаляются из tmp после завершения задачи

### Model & Language Options (OPTS)

- [ ] **OPTS-01**: Переключатель модели `whisper-large-v3` (качество) / `whisper-large-v3-turbo` (скорость); дефолт large-v3
- [ ] **OPTS-02**: Селектор языка распознавания со списком (Авто / ru / en / + основные); дефолт «Авто»
- [ ] **OPTS-03**: При «Авто» параметр `language` не передаётся в запрос; при явном выборе — передаётся код языка

### Output (OUT)

- [ ] **OUT-01**: По завершении транскрибации генерируется `transcript.srt` (субтитры с таймкодами)
- [x] **OUT-02**: По завершении транскрибации генерируется `transcript.txt` (сплошной текст)
- [x] **OUT-03**: Кнопка «Скопировать txt» помещает полный текст в буфер обмена
- [ ] **OUT-04**: Кнопка «Поделиться» открывает системный share-sheet с текстом расшифровки (для Telegram/заметок/GPT-приложения)
- [ ] **OUT-05**: Расшифровка отображается в виде читаемого текста на экране результата

### History (HIST)

- [ ] **HIST-01**: Каждая успешная транскрибация сохраняется в локальной истории (имя файла, дата, длительность, путь к txt/srt)
- [ ] **HIST-02**: Главный экран показывает список ранее расшифрованных файлов
- [ ] **HIST-03**: Пользователь может открыть запись из истории и заново скопировать/поделиться текстом
- [ ] **HIST-04**: Пользователь может удалить запись из истории (с удалением файлов)

### Error Handling & Robustness (ERR)

- [ ] **ERR-01**: При отсутствии API-ключей — экран onboarding с предложением добавить ключ
- [ ] **ERR-02**: При сетевой ошибке — пользователь видит понятное сообщение и кнопку «Повторить»
- [ ] **ERR-03**: При всех заблокированных ключах — ожидание до ближайшей разблокировки с индикацией обратного отсчёта

## v2 Requirements

Отложено на следующий milestone. Не входит в первый APK.

### Recording (REC)

- **REC-01**: Запись с микрофона прямо в приложении (m4a/AAC), готовая к транскрибации
- **REC-02**: Индикатор уровня сигнала во время записи
- **REC-03**: Пауза/возобновление записи

### Video Import (VID)

- **VID-01**: Импорт локальных видеофайлов (mp4 и пр.); извлечение аудиодорожки через ffmpeg
- **VID-02**: Видео не сохраняется, только извлечённое аудио в tmp

### YouTube (YT)

- **YT-01**: Ввод ссылки YouTube; скачивание только аудио через `youtube_explode_dart`
- **YT-02**: Решение по доступности из РФ (с/без VPN) после эксперимента — оставить / добавить backend-прокси / отказаться

### Platform Expansion (PLAT)

- **PLAT-01**: Windows-десктоп: `flutter build windows`, системный ffmpeg.exe через `Process.run`, sidebar layout
- **PLAT-02**: iOS: macOS-сборка + Apple Developer ($99/год), TestFlight/App Store

## Out of Scope

| Feature | Reason |
|---------|--------|
| Серверная FastAPI-часть | На устройстве не нужна, удлиняет стек |
| Telegram-бот | Унаследовано из LectureLog, нерелевантно для мобильного приложения |
| Docker | Не применимо к мобильному клиенту |
| Gemini/слайды-пайплайн из LectureLog | Это уже LLM-стадия; для MVP достаточно сырой расшифровки |
| Структурирование/анализ расшифровки внутри ezctx | Внешний GPT/Claude справится лучше; не размывает фокус |
| Зашитые в сборку Groq-ключи | Опасно для распространения; пользователь вводит свои |
| Облачная синхронизация истории между устройствами | Усложняет MVP, нет реальной потребности |

## Traceability

Карта «требование → фаза». Перебалансирована для vertical MVP: Phase 1 содержит минимальный сквозной слайс (FOUND + минимум KEYS/IMPORT/TRANS/OUT), а не только инфраструктуру.

| Requirement | Phase | Status |
|-------------|-------|--------|
| FOUND-01 | Phase 1 | Pending |
| FOUND-02 | Phase 1 | Pending |
| FOUND-03 | Phase 1 | Pending |
| KEYS-01 | Phase 1 | Pending |
| KEYS-02 | Phase 1 | Pending |
| KEYS-03 | Phase 3 | Pending |
| KEYS-04 | Phase 3 | Pending |
| KEYS-05 | Phase 3 | Pending |
| IMPORT-01 | Phase 1 | Pending |
| IMPORT-02 | Phase 1 | Pending |
| IMPORT-03 | Phase 2 | Pending |
| IMPORT-04 | Phase 2 | Pending |
| TRANS-01 | Phase 3 | Pending |
| TRANS-02 | Phase 3 | Pending |
| TRANS-03 | Phase 1 | Pending |
| TRANS-04 | Phase 2 | Pending |
| TRANS-05 | Phase 2 | Pending |
| TRANS-06 | Phase 2 | Pending |
| TRANS-07 | Phase 1 | Pending |
| TRANS-08 | Phase 2 | Pending |
| TRANS-09 | Phase 2 | Pending |
| TRANS-10 | Phase 2 | Pending |
| OPTS-01 | Phase 4 | Pending |
| OPTS-02 | Phase 4 | Pending |
| OPTS-03 | Phase 4 | Pending |
| OUT-01 | Phase 5 | Pending |
| OUT-02 | Phase 1 | Complete |
| OUT-03 | Phase 1 | Complete |
| OUT-04 | Phase 5 | Pending |
| OUT-05 | Phase 1 | Pending |
| HIST-01 | Phase 6 | Pending |
| HIST-02 | Phase 6 | Pending |
| HIST-03 | Phase 6 | Pending |
| HIST-04 | Phase 6 | Pending |
| ERR-01 | Phase 7 | Pending |
| ERR-02 | Phase 7 | Pending |
| ERR-03 | Phase 7 | Pending |

**Coverage:**
- v1 requirements: 36 total
- Mapped to phases: 36
- Unmapped: 0 ✓

**Phase distribution:**
- Phase 1 (Walking Skeleton): 12 req
- Phase 2 (Real Lectures): 8 req
- Phase 3 (Multi-Key Pool): 5 req
- Phase 4 (Model & Language): 3 req
- Phase 5 (Output & Share): 2 req
- Phase 6 (History): 4 req
- Phase 7 (Error Polish): 3 req

---
*Requirements defined: 2026-05-16*
*Last updated: 2026-05-16 — Traceability rebalanced for vertical MVP*
