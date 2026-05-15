# ezctx

## What This Is

Кроссплатформенное (стартуем с Android) Flutter-приложение, которое локально извлекает текстовый контекст из аудио/видео через Groq Whisper API. Цель — за минуты получить готовую расшифровку на телефоне и сразу отдать её в LLM (ChatGPT/Claude) для дальнейшего анализа: поиска замечаний преподавателя, советов, выделения сути лекции.

## Core Value

Пользователь записал лекцию на телефон → открыл ezctx → выбрал файл → через несколько минут получил готовый txt в буфере обмена или поделился в GPT. Без перегона жирного аудио на компьютер.

## Requirements

### Validated

<!-- Shipped and confirmed valuable. -->

(None yet — ship to validate)

### Active

<!-- Current scope (v1, Android). Building toward these. -->

- [ ] Импорт локальных аудиофайлов (mp3/m4a/wav и др. форматы из whitelist Groq)
- [ ] Транскрибация через Groq Whisper API (large-v3 / turbo переключатель)
- [ ] Пул API-ключей с round-robin и rate-limit защитой (порт из LectureLog)
- [ ] Чанкование файлов > 19 MB через ffmpeg
- [ ] Параллельная отправка чанков
- [ ] Сборка результата с таймкодами (transcript.srt + transcript.txt)
- [ ] Выбор языка распознавания (Авто / ru / en / …)
- [ ] Настройки: ввод и хранение Groq API ключей (flutter_secure_storage)
- [ ] UI-индикация статуса ключей (активен / заблокирован до HH:MM:SS, остаток квоты)
- [ ] Кнопка «Скопировать txt» в буфер обмена
- [ ] Share intent (Telegram, заметки, GPT-приложение)
- [ ] История расшифровок с возможностью открыть и скопировать заново

### Out of Scope

<!-- Explicit boundaries with reasoning. -->

- Запись с микрофона в самом приложении — v2 (есть сторонние диктофоны; быстрее довести MVP)
- Импорт локальных видеофайлов — v2 (фокус v1 на чистом аудио-пайплайне)
- YouTube по ссылке — v2 (экспериментально на Android, может не работать без VPN из РФ)
- Windows-десктоп — отдельный milestone после Android v1
- iOS — отдельный milestone (требует Mac + Apple Developer $99/год)
- LLM-обработка расшифровки внутри приложения — намеренно отдано внешним GPT/Claude
- FastAPI-серверная часть и Telegram-бот из LectureLog — на устройстве не нужны
- Зашитые в сборку API-ключи — пользователь вводит свои сам (безопасность распространения)
- Структурирование/обработка слайдов (Gemini-пайплайн из LectureLog) — отдельная LLM-стадия, не MVP

## Context

- **Источник кода:** ключевая логика (пул ключей `key_pool.py`, чанкование и параллельная отправка `transcribe.py`) портируется из существующего Python/FastAPI проекта `~/projects/LectureLog/` в Dart.
- **Дизайн:** уже существует React-прототип в `design/` (design-canvas.jsx, screens.jsx, styles.css, скриншоты). Переносится во Flutter-виджеты механически.
- **Реальный workflow пользователя:** записывает аудио с лекций на телефон, сейчас вынужден перегонять жирные файлы на компьютер для LectureLog. ezctx убирает этот шаг.
- **Groq Free Tier ограничения:** 19.5 MB на файл, RPM/RPD на ключ, нужна ротация нескольких ключей.
- **Целевые форматы Groq:** flac, mp3, mp4, mpeg, mpga, m4a, ogg, wav, webm.

## Constraints

- **Tech stack**: Flutter (Dart) — единый кодбейз под Android/Windows/iOS, зрелый `ffmpeg_kit_flutter`, простой перенос React-дизайна.
- **Платформа v1**: только Android — собирается с Windows+WSL без Mac.
- **API**: только Groq Whisper (free tier), без серверной части.
- **Бюджет на распространение**: $0 на v1 (APK + бета через Firebase App Distribution), Google Play ($25 разово) — по необходимости.
- **Хранение секретов**: API-ключи только в `flutter_secure_storage`, никогда не в репозитории и не в сборке.
- **ffmpeg на Android**: через `ffmpeg_kit_flutter` (содержит ffmpeg + ffprobe).
- **Размер чанка**: ≤ 19 MB (баланс битрейта/длительности; базово 20 мин при mp3 128 kbps).

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Flutter (Dart) как стек | Один кодбейз на все платформы, есть React-дизайн под перенос, ffmpeg_kit_flutter | — Pending |
| Android-first для v1 | Реальный сценарий пользователя — мобильная запись; собирается с Windows без Mac | — Pending |
| v1 = только импорт аудио | Самый узкий MVP, доводит ядро (Groq pipeline) до полезного состояния быстрее | — Pending |
| Запись с микрофона → v2 | Существуют сторонние диктофоны; не блокирует core value | — Pending |
| Видео и YouTube → v2 | Видео расширяет пайплайн; YouTube на Android экспериментален | — Pending |
| Переключатель large-v3 / turbo в v1 | Дешёвая фича, важна для баланса качество/скорость на длинных лекциях | — Pending |
| Пользователь вводит Groq-ключи сам | Безопасность распространения; ключи нельзя зашивать в публичный APK | — Pending |
| История расшифровок в v1 | Пользователь возвращается к одной лекции несколько раз, не хочет распознавать заново | — Pending |
| LLM-стадия не входит в ezctx | Внешние GPT/Claude лучше любого встроенного решения; ezctx — только context extractor | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-05-16 after initialization*
