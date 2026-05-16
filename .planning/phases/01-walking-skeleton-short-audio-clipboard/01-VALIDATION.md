---
phase: 1
slug: walking-skeleton-short-audio-clipboard
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-16
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter test (встроен в SDK) |
| **Config file** | `pubspec.yaml` (dev_dependencies: flutter_test) |
| **Quick run command** | `flutter test --name "unit"` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter analyze && flutter test`
- **After every plan wave:** Run `flutter test` + ручная проверка на устройстве
- **Before `/gsd:verify-work`:** Full suite green + APK устанавливается и запускается
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | Status |
|---------|------|------|-------------|-----------|-------------------|--------|
| 1-01-01 | 01 | 1 | FOUND-01 | build | `flutter build apk --debug` | ⬜ pending |
| 1-01-02 | 01 | 1 | FOUND-02 | analyze | `flutter analyze` | ⬜ pending |
| 1-02-01 | 02 | 1 | KEYS-01 | unit | `flutter test test/secure_storage_test.dart` | ⬜ pending |
| 1-02-02 | 02 | 1 | KEYS-02 | unit | `flutter test test/secure_storage_test.dart` | ⬜ pending |
| 1-03-01 | 03 | 2 | IMPORT-01 | unit | `flutter test test/file_picker_test.dart` | ⬜ pending |
| 1-03-02 | 03 | 2 | IMPORT-02 | unit | `flutter test test/file_picker_test.dart` | ⬜ pending |
| 1-04-01 | 04 | 2 | TRANS-03 | unit | `flutter test test/groq_service_test.dart` | ⬜ pending |
| 1-04-02 | 04 | 2 | TRANS-07 | unit | `flutter test test/groq_service_test.dart` | ⬜ pending |
| 1-05-01 | 05 | 3 | OUT-02 | manual | Вставка текста в Telegram | ⬜ pending |
| 1-05-02 | 05 | 3 | OUT-03 | manual | Скопировать → вставить | ⬜ pending |
| 1-05-03 | 05 | 3 | OUT-05 | manual | APK install + запуск | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/secure_storage_test.dart` — моки для KEYS-01, KEYS-02
- [ ] `test/file_picker_test.dart` — моки для IMPORT-01, IMPORT-02
- [ ] `test/groq_service_test.dart` — моки HTTP для TRANS-03, TRANS-07

*flutter_test уже в SDK — дополнительная установка не нужна.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| APK устанавливается без падений | OUT-05, FOUND-01 | Требует физического устройства | `adb install build/app/outputs/flutter-apk/app-debug.apk` |
| Текст вставляется в Telegram | OUT-02 | Требует стороннего приложения | Нажать «Скопировать», открыть Telegram, вставить |
| API-ключ переживает перезапуск | KEYS-02 | Требует перезапуска приложения | Ввести ключ, убить приложение, открыть снова |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
