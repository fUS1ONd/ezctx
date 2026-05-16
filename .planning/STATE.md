# STATE: ezctx

**Last updated:** 2026-05-16

## Project Reference

- **Project:** ezctx — Android-first Flutter-приложение для локальной расшифровки аудио через Groq Whisper
- **Core value:** Студент записал лекцию на телефон → импортировал в ezctx → через минуты получил txt в буфере / share, без перегона на ПК
- **Target artifact (v1):** Установленный на Android APK, полностью покрывающий core value
- **Stack:** Flutter (Dart), `ffmpeg_kit_flutter`, `flutter_secure_storage`, `file_picker`, Groq Whisper API
- **Mode:** Vertical MVP (каждая фаза = end-to-end working slice)
- **Granularity:** standard
- **Parallelization:** enabled

## Current Position

- **Milestone:** v1 Android MVP
- **Phase:** 0 (planning complete, ready to start Phase 1)
- **Plan:** —
- **Status:** Roadmap approved, awaiting `/gsd:plan-phase 1`
- **Progress:** 0/7 phases complete `[░░░░░░░] 0%`

## Phase Map

| # | Phase | Status | Plans |
|---|-------|--------|-------|
| 1 | Walking Skeleton (Short Audio → Clipboard) | Not started | TBD |
| 2 | Real Lectures (Chunking & Progress) | Not started | TBD |
| 3 | Multi-Key Pool & Rate-Limit UI | Not started | TBD |
| 4 | Model & Language Controls | Not started | TBD |
| 5 | Output Formats & Sharing | Not started | TBD |
| 6 | History | Not started | TBD |
| 7 | Error Handling & Onboarding Polish | Not started | TBD |

## Performance Metrics

- **Phases completed:** 0/7
- **Plans completed:** 0
- **Requirements covered:** 0/36 (0%)

## Accumulated Context

### Key Decisions Logged

- **Stack:** Flutter + Dart (один кодбейз, есть React-прототип в `design/`, зрелый `ffmpeg_kit_flutter`).
- **v1 platform:** только Android (собирается с Windows+WSL, без Mac).
- **Source of truth для бэкенда:** портируется из `~/projects/LectureLog/` (`transcribe.py`, `key_pool.py`) на Dart.
- **Secrets:** API-ключи Groq вводит пользователь, хранятся в `flutter_secure_storage`. В сборку не зашиваются.
- **Чанк:** ≤ 19 MB (Groq Free Tier лимит 19.5 MB), базовый сегмент 1200 сек mp3 128k.
- **Дизайн-источник:** `design/` (React-прототип) — переносится во Flutter-виджеты механически в Phase 1.

### Open Questions / TODOs

- Concurrency per single Groq key — экспериментально определить реальный потолок (RPM vs. одновременные in-flight). Решение откладываем до Phase 2/3, когда появится нагрузка для тестов.
- ffmpeg-параметры для оптимального чанка (downmix mono + 16 kHz?) — уточнить в Phase 2 на реальных лекциях.

### Blockers

None.

## Session Continuity

- **Next action:** `/gsd:plan-phase 1` — декомпозировать Phase 1 (Walking Skeleton) на планы.
- **Last session:** инициализация проекта, генерация PROJECT.md / REQUIREMENTS.md / ROADMAP.md / STATE.md.

---
*State initialized: 2026-05-16*
