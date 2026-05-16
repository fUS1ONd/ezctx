# Phase 1: Walking Skeleton (Short Audio → Clipboard) - Context

**Gathered:** 2026-05-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Минимальный end-to-end слайс: Flutter-проект создан, собирается debug APK на Android,
пользователь может выбрать короткий аудиофайл (<19 MB), транскрибировать через Groq Whisper
и скопировать результат в буфер обмена. Плюс CI/CD: каждый push в main собирает debug APK
и публикует как GitHub Actions Artifact.

Не входит в фазу: чанкование (Фаза 2), пул ключей (Фаза 3), share intent (Фаза 5).

</domain>

<decisions>
## Implementation Decisions

### Настройка проекта и Flutter SDK
- **D-01:** Flutter SDK не установлен — нужна установка локально в WSL и в CI (GitHub Actions).
- **D-02:** Структура пакетов: `lib/core/`, `lib/features/`, `lib/ui/` согласно REQUIREMENTS (FOUND-02).
- **D-03:** Зависимости v1: `http`, `file_picker`, `flutter_secure_storage`, `ffmpeg_kit_flutter`, `path_provider`.

### GitHub CI/CD
- **D-04:** Репозиторий: `git@github.com:fUS1ONd/ezctx.git` — уже существует на GitHub.
- **D-05:** Триггер: каждый push в ветку `main` запускает сборку.
- **D-06:** Артефакт: **debug APK** (release не нужен — нет keystore, нет Google Play в v1).
- **D-07:** Доставка APK: **GitHub Actions Artifacts** — скачивается вручную из интерфейса GitHub и устанавливается на телефон через adb или прямую установку.
- **D-08:** CI использует ubuntu-latest с официальным `subosito/flutter-action` для установки Flutter SDK.
- **D-09:** Версия Flutter в CI: та же, что будет установлена локально (закрепить в `flutter-version` параметре action).

### Локальная разработка и тестирование
- **D-10:** Тестирование: физический Android-телефон по USB.
- **D-11:** Из WSL нужно прокинуть USB через `usbipd-win` (одноразовая настройка ~5 мин).
- **D-12:** Команда запуска: `flutter run` в WSL с телефоном как target-устройством.
- **D-13:** Flutter Doctor должен показывать Connected device перед разработкой.

### Дизайн-система
- **D-14:** Дизайн переносится из React-прототипа (`design/`): цвета, шрифты, базовые компоненты.
- **D-15:** Дизайн-прототип: `design/screens.jsx`, `design/styles.css` — исходный материал для Flutter-виджетов.

### Groq API — базовая транскрибация
- **D-16:** Короткий файл (<19 MB) отправляется одним запросом, без сегментации (TRANS-03).
- **D-17:** Параметры запроса: `response_format=verbose_json`, `timestamp_granularities=[word]` (TRANS-07).
- **D-18:** Модель по умолчанию: `whisper-large-v3`.
- **D-19:** API-ключ вводится пользователем, хранится в `flutter_secure_storage` (KEYS-01, KEYS-02).

### Claude's Discretion
- Конкретная версия Flutter SDK для фиксации в CI — выбрать стабильный канал (`stable`), последнюю стабильную версию на момент создания workflow.
- Структура GitHub Actions workflow файла — стандартный подход с кешированием pub packages.
- Минимальная версия Android SDK (minSdkVersion) — определить по `file_picker` и `flutter_secure_storage`.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Дизайн-прототип
- `design/screens.jsx` — экраны приложения (главный, настройки, результат)
- `design/styles.css` — цветовая схема, шрифты, базовые стили
- `design/design-canvas.jsx` — canvas дизайна

### Требования проекта
- `.planning/REQUIREMENTS.md` — полный список требований v1, особенно FOUND-01..03, KEYS-01..02, IMPORT-01..02, TRANS-03, TRANS-07, OUT-02..03, OUT-05
- `.planning/ROADMAP.md` §Phase 1 — Success Criteria (5 критериев приёмки)
- `.planning/PROJECT.md` — ограничения и ключевые решения

### GitHub CI/CD
- `git@github.com:fUS1ONd/ezctx.git` — целевой репозиторий

### Нет внешних ADR/SPEC — требования полностью покрыты выше

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `design/` (React-прототип) — готовый дизайн для механического переноса во Flutter-виджеты
- `~/projects/LectureLog/key_pool.py` — логика пула ключей (порт на Dart в Фазе 3)
- `~/projects/LectureLog/transcribe.py` — логика чанкования и отправки (порт в Фазах 2-3)

### Established Patterns
- Flutter-структура: `lib/core/`, `lib/features/`, `lib/ui/` — следовать с первого файла
- Секреты: только `flutter_secure_storage`, никогда SharedPreferences или хардкод

### Integration Points
- `file_picker` → валидация whitelist Groq → Groq API HTTP-запрос → экран результата
- `flutter_secure_storage` → хранение API-ключа → использование в HTTP-запросе

</code_context>

<specifics>
## Specific Ideas

- Пользователь хочет тестировать на физическом Android по USB прямо во время разработки в VS Code (WSL).
- CI собирает APK на каждый push — пользователь скачивает из GitHub и устанавливает на телефон для тестирования билдов.
- Репозиторий: `git@github.com:fUS1ONd/ezctx.git` (SSH, уже создан).

</specifics>

<deferred>
## Deferred Ideas

- **Эмулятор Android** — пользователь предпочёл физическое устройство для v1; эмулятор можно добавить позже.
- **Firebase App Distribution** — автоматическая раздача APK тестерам — отложено на будущее (пока достаточно GitHub Artifacts).
- **Release APK + keystore** — не нужен до Google Play (v2+).
- **usbipd-win настройка** — техническая документация по WSL+USB выходит за рамки фазы, но нужна разработчику локально.

</deferred>

---

*Phase: 1-Walking Skeleton (Short Audio → Clipboard)*
*Context gathered: 2026-05-16*
