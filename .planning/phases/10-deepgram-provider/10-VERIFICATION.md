---
phase: 10-deepgram-provider
verified: 2026-06-10T00:00:00Z
status: human_needed
score: 8/8 must-haves verified
overrides_applied: 0
human_verification:
  - test: "End-to-end транскрипция с реальным Deepgram-ключом и реальным аудиофайлом"
    expected: "После выбора модели Nova-3 и добавления DG-ключа файл обрабатывается до конца, txt с таймкодами появляется в буфере обмена"
    why_human: "Требует валидного Deepgram API-ключа и реального устройства/эмулятора; результат API недетерминирован"
  - test: "Поведение detected_language при явном language=ru"
    expected: "Deepgram возвращает detected_language в ответе; при отсутствии fallback на options.language.isoCode работает корректно"
    why_human: "Open Question A1 — поведение Deepgram API наблюдаемо только на реальном запросе с конкретным ключом"
---

# Phase 10: DeepgramProvider — Verification Report

**Phase Goal:** Add Deepgram nova-3 as a second transcription provider alongside Groq Whisper, with namespace-isolated key storage, DI-wired KeyPool, and provider routing by options.model.provider.
**Verified:** 2026-06-10
**Status:** human_needed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | DeepgramProvider строит raw-bytes POST на `https://api.deepgram.com/v1/listen` с `model=nova-3&smart_format=true&paragraphs=true` | ✓ VERIFIED | `deepgram_provider.dart:46-57` — `Uri.parse(AppConstants.deepgramApiUrl).replace(queryParameters: {...})` с `model: options.model.apiValue`, `smart_format: 'true'`, `paragraphs: 'true'` |
| 2 | Запрос несёт заголовок `Authorization: Token <key>` (не Bearer) и `Content-Type: audio/ogg`; API-ключ только в заголовке, не в URL | ✓ VERIFIED | `deepgram_provider.dart:64-66` — `'Authorization': 'Token $apiKey'`, `'Content-Type': 'audio/ogg'`; ключ отсутствует в `queryParameters` |
| 3 | Парсинг `paragraphs.paragraphs[].sentences[]` даёт список `TranscriptionSegment{start,end,text}`; fallback на `words[]`, затем на плоский `transcript` | ✓ VERIFIED | `deepgram_provider.dart:148-210` — трёхуровневый fallback реализован; тесты 1-3 в `deepgram_provider_test.dart` покрывают все три пути |
| 4 | `401→AuthException`, `402→KeyExhaustedException`, `429→RateLimitException`, `504/5xx→NetworkException` | ✓ VERIFIED | `deepgram_provider.dart:81-106`; тесты 7-10 (`deepgram_provider_test.dart:211, 226, 241, 256`) — все 4 маппинга покрыты |
| 5 | `concurrencyFor(0)==0` и `concurrencyFor(n>0)==5` | ✓ VERIFIED | `deepgram_provider.dart:215` — `aliveKeyCount > 0 ? 5 : 0`; тест 11 в `deepgram_provider_test.dart` |
| 6 | `SecureStorageServiceImpl` параметризован по namespace; Groq-ключи под `groq_api_keys_v1`, Deepgram под `deepgram_api_keys_v1`; namespaces не пересекаются | ✓ VERIFIED | `secure_storage_service.dart:34-42` — `String storageKey = AppConstants.storageKeyApiKeys` (default Groq); `final String _storageKey`; `static const _storageKey` удалён |
| 7 | `deepgramKeyPoolProvider` существует в DI; `main.dart` создаёт два KeyPool; `ProcessingScreen` выбирает `pool+provider` по `options.model.provider` | ✓ VERIFIED | `service_providers.dart:15-17`; `main.dart:22-43`; `processing_screen.dart:132-139` — `_isDeepgram` flag + динамический выбор; `transcriptionProviderProvider` полностью удалён (grep: 0 ссылок) |
| 8 | Сообщение `ChunkedMissingKey` динамично: `'API-ключ Deepgram'` при Deepgram, `'API-ключ Groq'` при Groq | ✓ VERIFIED | `processing_screen.dart:427-429` — ternary по `_isDeepgram` |

**Score:** 8/8 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/features/transcription/deepgram_provider.dart` | DeepgramProvider — реализация TranscriptionProvider для nova-3 | ✓ VERIFIED | 220 строк, `class DeepgramProvider implements TranscriptionProvider`, raw-bytes POST |
| `test/unit/deepgram_provider_test.dart` | Юнит-тесты запроса/парсинга/маппинга ошибок/конкурентности | ✓ VERIFIED | 272 строки, 11 тест-кейсов, MockClient, без MultipartRequest |
| `test/fixtures/deepgram_nova3_response.json` | Фикстура с paragraphs/sentences/words | ✓ VERIFIED | Файл существует |
| `test/fixtures/deepgram_nova3_response_empty.json` | Фикстура пустого ответа (тишина) | ✓ VERIFIED | Файл существует |
| `lib/core/constants/app_constants.dart` | `deepgramApiUrl` + `storageKeyDeepgramApiKeys` | ✓ VERIFIED | Строки 18 и 50 |
| `lib/core/storage/secure_storage_service.dart` | Параметризованный по namespace `SecureStorageServiceImpl` | ✓ VERIFIED | `String storageKey = AppConstants.storageKeyApiKeys` + `final String _storageKey` |
| `lib/core/providers/storage_providers.dart` | `deepgramSecureStorageProvider` | ✓ VERIFIED | Строки 13-17, `storageKey: AppConstants.storageKeyDeepgramApiKeys` |
| `lib/core/providers/repository_providers.dart` | `deepgramApiKeyRepoProvider` + `deepgramApiKeysProvider` | ✓ VERIFIED | Строки 22-29 |
| `lib/core/providers/service_providers.dart` | `deepgramKeyPoolProvider` (override-only) | ✓ VERIFIED | Строки 15-17 |
| `lib/main.dart` | Bootstrap двух пулов | ✓ VERIFIED | Строки 22-43, оба `overrideWithValue` |
| `lib/ui/screens/processing_screen.dart` | Выбор pool+provider по провайдеру модели | ✓ VERIFIED | Строки 132-139, динамический ChunkedMissingKey на строках 427-429 |
| `CLAUDE.md` | Обновлённое ограничение API (два провайдера) | ✓ VERIFIED | Строка 16: `Groq Whisper и Deepgram nova-3 (оба free tier)` |
| `.planning/phases/10-deepgram-provider/10-VALIDATION.md` | `nyquist_compliant: true`, `wave_0_complete: true`, `status: complete` | ✓ VERIFIED | Строки 4-6 frontmatter |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `deepgram_provider.dart` | `AppConstants.deepgramApiUrl` | `Uri.parse(AppConstants.deepgramApiUrl)` | ✓ WIRED | Строка 46 |
| `deepgram_provider.dart` | `TranscriptionProvider` | `implements TranscriptionProvider` | ✓ WIRED | Строка 17 |
| `storage_providers.dart` | `AppConstants.storageKeyDeepgramApiKeys` | `SecureStorageServiceImpl(storageKey: ...)` | ✓ WIRED | Строки 15-16 |
| `repository_providers.dart` | `deepgramSecureStorageProvider` | `ref.watch(deepgramSecureStorageProvider)` | ✓ WIRED | Строка 23 |
| `main.dart` | `deepgramApiKeyRepoProvider` | `bootstrap.read(...).listKeys()` | ✓ WIRED | Строка 22 |
| `main.dart` | `deepgramKeyPoolProvider` | `.overrideWithValue(deepgramKeyPool)` | ✓ WIRED | Строка 41 |
| `processing_screen.dart` | `DeepgramProvider` | `_isDeepgram ? DeepgramProvider() : GroqProvider()` | ✓ WIRED | Строка 139 |
| `processing_screen.dart` | `deepgramKeyPoolProvider` | `ref.read(deepgramKeyPoolProvider)` | ✓ WIRED | Строка 137 |

---

### Requirements Coverage

| Requirement | Source Plan | Status | Evidence |
|-------------|------------|--------|---------|
| R-DG-01 | 10-01 | ✓ SATISFIED | Token-заголовок, audio/ogg, raw bytes, ключ не в URL — `deepgram_provider.dart:64-68` |
| R-DG-02 | 10-01 | ✓ SATISFIED | Парсинг `paragraphs.paragraphs[].sentences[]` → `TranscriptionSegment` — `deepgram_provider.dart:148-177` |
| R-DG-03 | 10-01 | ✓ SATISFIED | Fallback `words[]` при пустых paragraphs, fallback plain transcript — `deepgram_provider.dart:179-210` |
| R-DG-04 | 10-01 | ✓ SATISFIED | `401→AuthException`, `402→KeyExhaustedException`, `429→RateLimitException`, `5xx→NetworkException` — `deepgram_provider.dart:81-106` |
| R-DG-05 | 10-01 | ✓ SATISFIED | `concurrencyFor`: `aliveKeyCount>0 → 5`, `0 → 0` — `deepgram_provider.dart:215` |
| R-DG-06 | 10-03 | ✓ SATISFIED | Nova-3 без DG-ключей → `ChunkedMissingKey`; тест `chunked_transcription_controller_test.dart:327-358` |
| R-DG-07 | 10-02/10-04 | ✓ SATISFIED | Namespace-рефактор не сломал Groq; `SecureStorageServiceImpl` default = `groq_api_keys_v1`; полный прогон 170/170 по данным SUMMARY |
| R-DG-08 | 10-03 | ✓ SATISFIED | `deepgramKeyPoolProvider.overrideWithValue` в `home_screen_smoke_test.dart:23` |

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `10-VALIDATION.md` | 44-51 | Статусы `⬜ pending` в Per-Task Verification Map не обновлены на `✅` | ℹ️ Info | Только документационный артефакт — не влияет на код; флаги `nyquist_compliant` и `wave_0_complete` проставлены корректно |

Долговые маркеры TBD/FIXME/XXX в файлах фазы: не обнаружены.

---

### Human Verification Required

#### 1. End-to-end Nova-3 транскрипция на устройстве

**Test:** Добавить Deepgram API-ключ в настройках → выбрать модель Nova-3 → выбрать аудиофайл → запустить обработку
**Expected:** Транскрипция завершается успешно, результат с таймкодами появляется на экране результатов и копируется в буфер обмена
**Why human:** Требует валидного Deepgram API-ключа, реального устройства/эмулятора и реального аудиофайла; ответ API недетерминирован

#### 2. Поведение detected_language (Open Question A1)

**Test:** Выполнить реальный запрос с `language=ru` → проверить поле `detected_language` в ответе Deepgram
**Expected:** При явном языке Deepgram либо возвращает `detected_language`, либо fallback на `options.language.isoCode` корректно применяется
**Why human:** Поведение Deepgram API при явном языке не задокументировано в spec; наблюдаемо только при реальном запросе

---

### Gaps Summary

Автоматически верифицируемых пробелов не обнаружено. Все 8 must-have truths подтверждены кодовыми свидетельствами. Два пункта требуют ручной проверки на реальном устройстве (end-to-end + Open Question A1).

**Примечание:** `10-03-SUMMARY.md` отсутствует в tracking (зафиксировано в `10-04-SUMMARY.md` как известный факт), но коммиты плана 10-03 (`7512bbd`, `088728c`, `f560fe2`) существуют и все артефакты плана присутствуют в кодовой базе. Это информационная запись, не блокер.

---

_Verified: 2026-06-10_
_Verifier: Claude (gsd-verifier)_
