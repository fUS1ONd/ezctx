---
phase: 10
slug: deepgram-provider
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-10
---

# Phase 10 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (встроен) |
| **Config file** | none — стандартный `flutter test` |
| **Quick run command** | `/opt/flutter/bin/flutter test test/unit/deepgram_provider_test.dart` |
| **Full suite command** | `/opt/flutter/bin/flutter test` |
| **Estimated runtime** | ~60 seconds (full suite) |

> Запуск тестов — только через `ctx_execute`/`ctx_batch_execute` (правило проекта), не через Bash.

---

## Sampling Rate

- **After every task commit:** Run quick command (`deepgram_provider_test.dart`)
- **After every plan wave:** Run full suite (`flutter test`)
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Req | Behavior | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|-----|----------|------------|-----------------|-----------|-------------------|-------------|--------|
| R-DG-01 | Правильный URL/заголовки/body (`Authorization: Token`, `Content-Type: audio/ogg`, raw bytes) | T-10-01 | Ключ только в заголовке, не в URL/логах | unit | `flutter test test/unit/deepgram_provider_test.dart` | ❌ W0 | ⬜ pending |
| R-DG-02 | Парсинг `paragraphs` → `TranscriptionSegment{start,end,text}` | — | N/A | unit | `flutter test test/unit/deepgram_provider_test.dart` | ❌ W0 | ⬜ pending |
| R-DG-03 | Fallback на `words[]` при пустых paragraphs | — | N/A | unit | `flutter test test/unit/deepgram_provider_test.dart` | ❌ W0 | ⬜ pending |
| R-DG-04 | Маппинг `401→Auth`, `402→KeyExhausted`, `429→RateLimit`, `504/5xx→Network` | T-10-02 | Тело ошибки не утекает в текст исключения | unit | `flutter test test/unit/deepgram_provider_test.dart` | ❌ W0 | ⬜ pending |
| R-DG-05 | `concurrencyFor`: `aliveKeyCount>0 → 5`, `0 → 0` | — | N/A | unit | `flutter test test/unit/deepgram_provider_test.dart` | ❌ W0 | ⬜ pending |
| R-DG-06 | Nova-3 без DG-ключей → `ChunkedMissingKey` по пулу провайдера | — | N/A | unit | `flutter test test/features/transcription/chunked_transcription_controller_test.dart` | ✅ | ⬜ pending |
| R-DG-07 | Регрессия: существующие Groq-тесты зелёные (namespace storage не сломал Groq) | T-10-03 | Раздельные namespace ключей не пересекаются | regression | `flutter test test/unit/` | ✅ | ⬜ pending |
| R-DG-08 | DI: `deepgramKeyPoolProvider` переопределяется в `main` | — | N/A | smoke | `flutter test test/widget/home_screen_smoke_test.dart` | ✅ (расширить) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/unit/deepgram_provider_test.dart` — новый файл, covers R-DG-01..05
- [ ] `test/fixtures/deepgram_nova3_response.json` — JSON-фикстура с `paragraphs`/`sentences`/`words`
- [ ] `test/fixtures/deepgram_nova3_response_empty.json` — фикстура для тишины/пустого ответа (R-DG-03 edge)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| End-to-end Nova-3 транскрипция на реальном устройстве с реальным DG-ключом | Цель фазы | Требует валидного Deepgram API-ключа и реального аудио; недетерминированный ответ API | Ввести DG-ключ в настройках → выбрать модель Nova-3 → обработать аудиофайл → проверить, что txt с таймкодами появился в буфере |
| Подтверждение Open Question A1: `detected_language` при явном `language=ru` | R-DG-02 | Поведение Deepgram API наблюдаемо только в проде | Прогнать реальный запрос с `language=ru`, проверить наличие `detected_language` в ответе; fallback на `options.language.isoCode` уже в коде |

---

## Validation Sign-Off

- [ ] All tasks have automated verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (`deepgram_provider_test.dart` + 2 фикстуры)
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter (планировщик/исполнитель проставит после Wave 0)

**Approval:** pending
