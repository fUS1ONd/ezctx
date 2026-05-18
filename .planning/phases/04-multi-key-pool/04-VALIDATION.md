---
phase: 4
slug: multi-key-pool
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-17
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (SDK) |
| **Config file** | none — нет отдельного файла |
| **Quick run command** | `flutter test test/features/settings/groq_key_pool_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/features/settings/groq_key_pool_test.dart`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 4-??-01 | GroqKeyPool | 1 | TRANS-01 | — | round-robin выдаёт ключи по очереди | unit | `flutter test test/features/settings/groq_key_pool_test.dart` | ❌ W0 | ⬜ pending |
| 4-??-02 | GroqKeyPool | 1 | TRANS-01 | — | заблокированный ключ пропускается | unit | `flutter test test/features/settings/groq_key_pool_test.dart` | ❌ W0 | ⬜ pending |
| 4-??-03 | GroqKeyPool | 1 | TRANS-01 | — | все ключи заблокированы → ждём | unit | `flutter test test/features/settings/groq_key_pool_test.dart` | ❌ W0 | ⬜ pending |
| 4-??-04 | GroqKeyPool | 1 | TRANS-01 | — | таймаут 10 мин → AllKeysBlockedException | unit | `flutter test test/features/settings/groq_key_pool_test.dart` | ❌ W0 | ⬜ pending |
| 4-??-05 | Rate parsing | 1 | TRANS-02 | — | парсинг retry-after (int) | unit | `flutter test test/unit/groq_api_service_rate_limit_test.dart` | ❌ W0 | ⬜ pending |
| 4-??-06 | Rate parsing | 1 | TRANS-02 | — | парсинг x-ratelimit-reset-requests ("2m59.56s") | unit | `flutter test test/unit/groq_api_service_rate_limit_test.dart` | ❌ W0 | ⬜ pending |
| 4-??-07 | Rate parsing | 1 | TRANS-02 | — | fallback 60с если заголовки отсутствуют | unit | `flutter test test/unit/groq_api_service_rate_limit_test.dart` | ❌ W0 | ⬜ pending |
| 4-??-08 | ApiKeysScreen | 2 | KEYS-05 | — | UI показывает "Активен" для живого ключа | widget | `flutter test test/widget/api_keys_screen_status_test.dart` | ❌ W0 | ⬜ pending |
| 4-??-09 | ApiKeysScreen | 2 | KEYS-05 | — | UI показывает "До HH:MM:SS" для заблокированного | widget | `flutter test test/widget/api_keys_screen_status_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/features/settings/groq_key_pool_test.dart` — stubs для TRANS-01
- [ ] `test/unit/groq_api_service_rate_limit_test.dart` — stubs для TRANS-02
- [ ] `test/widget/api_keys_screen_status_test.dart` — stubs для KEYS-05

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Часовая лекция расшифровывается на двух ключах без вмешательства | TRANS-01 | Требует реального устройства и двух Groq-ключей | Загрузить 60+ мин файл, добавить 2 ключа, запустить транскрибацию, убедиться что оба ключа участвуют в логах |
| Ссылка https://console.groq.com/keys открывается в браузере | KEYS-04 | Системный вызов URL — не тестируется unit-тестами | Тап по ссылке в ApiKeysScreen, браузер должен открыться |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
