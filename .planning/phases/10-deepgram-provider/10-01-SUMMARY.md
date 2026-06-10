---
phase: 10-deepgram-provider
plan: "01"
subsystem: transcription
tags: [deepgram, nova3, provider, tdd, unit-tests]
dependency_graph:
  requires:
    - "lib/features/transcription/transcription_provider.dart"
    - "lib/core/error/app_exception.dart"
    - "lib/features/transcription/transcription_options.dart"
  provides:
    - "lib/features/transcription/deepgram_provider.dart"
    - "test/fixtures/deepgram_nova3_response.json"
    - "test/fixtures/deepgram_nova3_response_empty.json"
    - "test/unit/deepgram_provider_test.dart"
  affects:
    - "lib/core/constants/app_constants.dart"
tech_stack:
  added: []
  patterns:
    - "raw-bytes POST (не multipart) с Authorization: Token"
    - "TDD Wave-0: фикстуры + тест ПЕРЕД реализацией"
    - "fallback-цепочка: paragraphs.sentences → words → plain text"
key_files:
  created:
    - "lib/features/transcription/deepgram_provider.dart"
    - "test/unit/deepgram_provider_test.dart"
    - "test/fixtures/deepgram_nova3_response.json"
    - "test/fixtures/deepgram_nova3_response_empty.json"
  modified:
    - "lib/core/constants/app_constants.dart"
decisions:
  - "Raw-bytes POST, не multipart — Deepgram принимает audio/ogg напрямую в body"
  - "Authorization: Token (не Bearer) — требование Deepgram API"
  - "detected_language читается с уровня channel, не alternative"
  - "duration = end последнего параграфа (Deepgram не возвращает поле duration)"
  - "concurrencyFor: aliveKeyCount>0 → 5, 0 → 0"
metrics:
  duration_minutes: 30
  completed_date: "2026-06-10"
  tasks_completed: 3
  files_changed: 7
---

# Phase 10 Plan 01: DeepgramProvider — nova-3 raw-bytes POST

**One-liner:** DeepgramProvider с raw-bytes POST, Token-авторизацией, fallback-парсингом paragraphs/words/text и полным TDD-покрытием (11 тестов).

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Wave 0: фикстуры + RED тест | f5d494f | test/fixtures/*.json, test/unit/deepgram_provider_test.dart |
| 2 | Константы Deepgram в AppConstants | 5e854ae | lib/core/constants/app_constants.dart |
| 3 | Реализация DeepgramProvider (GREEN) | 5828796 | lib/features/transcription/deepgram_provider.dart |

## What Was Built

`DeepgramProvider` реализует `TranscriptionProvider` для Deepgram nova-3:

- **HTTP запрос:** `POST https://api.deepgram.com/v1/listen` с query-параметрами `model=nova-3&smart_format=true&paragraphs=true&detect_language=true` (или `language=ru`)
- **Заголовки:** `Authorization: Token <key>` (не Bearer), `Content-Type: audio/ogg`
- **Тело:** `Uint8List.fromList(bytes)` — raw bytes, не multipart
- **Таймаут:** 5 минут
- **Парсинг:** `results.channels[0].alternatives[0]` → paragraphs.sentences → TranscriptionSegment; fallback на words[], затем на plain transcript
- **Ошибки:** 401→AuthException, 402→KeyExhaustedException, 429→RateLimitException, 504/5xx→NetworkException; тело обрезается до 200 символов (T-10-02)
- **Конкурентность:** `concurrencyFor(n) = n>0 ? 5 : 0`

## Test Results

`flutter test test/unit/deepgram_provider_test.dart`: **11/11 PASSED**

| # | Тест | Результат |
|---|------|-----------|
| 1 | paragraphs→segments: количество и start первого | PASS |
| 2 | fallback words→segments при пустых paragraphs | PASS |
| 3 | fallback plain text при пустых paragraphs и words | PASS |
| 4 | URL params: detect_language=true при auto | PASS |
| 5 | URL params: language=ru при explicit | PASS |
| 6 | Headers: Authorization: Token + Content-Type: audio/ogg | PASS |
| 7 | 401 → AuthException | PASS |
| 8 | 402 → KeyExhaustedException | PASS |
| 9 | 429 → RateLimitException | PASS |
| 10 | 504 → NetworkException | PASS |
| 11 | concurrencyFor(0)==0, (1)==5, (3)==5 | PASS |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Восстановлены зависимые файлы из основной ветки**

- **Found during:** Task 3 (компиляция тестов)
- **Issue:** Worktree создан от base commit `4e1a742` (docs(10)) — в нём отсутствовали файлы, добавленные в предыдущих фазах позже этого коммита:
  - `lib/features/transcription/transcription_provider.dart` — полностью отсутствовал в git tree base
  - `lib/features/transcription/transcription_options.dart` — старая версия (79 строк) без `TranscriptionProviderId`, `TranscriptionModel.nova3`
  - `lib/core/error/app_exception.dart` — старая версия без `KeyExhaustedException`
- **Fix:** Файлы восстановлены в worktree из актуальных версий основного репозитория (`/root/projects/ezctx/lib/`)
- **Files modified:** transcription_options.dart, app_exception.dart, transcription_provider.dart (create)
- **Commit:** 5828796

## Requirements Coverage

| Req | Status |
|-----|--------|
| R-DG-01 | DONE — Token-заголовок, audio/ogg, raw bytes, ключ не в URL |
| R-DG-02 | DONE — парсинг paragraphs.paragraphs[].sentences[] |
| R-DG-03 | DONE — fallback words[] при пустых paragraphs |
| R-DG-04 | DONE — 401→Auth, 402→KeyExhausted, 429→RateLimit, 504/5xx→Network |
| R-DG-05 | DONE — concurrencyFor: aliveKeyCount>0 → 5, 0 → 0 |

## Decisions Made

1. Raw-bytes POST — Deepgram принимает `audio/ogg` в body напрямую, multipart не нужен
2. `Authorization: Token` (не Bearer) — задокументированное требование Deepgram API
3. `detected_language` читается с уровня `channels[0]`, не `alternatives[0]` (Pitfall 3)
4. `duration` вычисляется из `end` последнего параграфа/слова (Deepgram не возвращает поле `duration`)
5. `concurrencyFor` = 5 (фиксировано) при наличии ключей, 0 при отсутствии

## Threat Surface

Все угрозы из threat_model плана закрыты:

| Threat | Mitigation | Status |
|--------|-----------|--------|
| T-10-01 | Ключ только в заголовке Authorization, не в URL и не в логах | DONE |
| T-10-02 | Тело ошибки обрезается до 200 символов в NetworkException (safeBody) | DONE |

## Self-Check: PASSED

- lib/features/transcription/deepgram_provider.dart: EXISTS
- test/unit/deepgram_provider_test.dart: EXISTS
- test/fixtures/deepgram_nova3_response.json: EXISTS
- test/fixtures/deepgram_nova3_response_empty.json: EXISTS
- Commit f5d494f: EXISTS (test - Wave 0)
- Commit 5e854ae: EXISTS (feat - AppConstants)
- Commit 5828796: EXISTS (feat - DeepgramProvider GREEN)
