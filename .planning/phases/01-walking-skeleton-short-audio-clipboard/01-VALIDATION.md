---
phase: 1
slug: walking-skeleton-short-audio-clipboard
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-16
audited: 2026-05-17
---

# Phase 1 — Validation Strategy

> Per-phase validation contract для feedback-sampling во время выполнения.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter test (встроен в SDK) |
| **Config file** | `pubspec.yaml` (dev_dependencies: flutter_test, mockito) |
| **Quick run command** | `/opt/flutter/bin/flutter test test/unit/` |
| **Full suite command** | `/opt/flutter/bin/flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** `flutter analyze && flutter test`
- **After every plan wave:** `flutter test` + ручная проверка на устройстве
- **Before `/gsd:verify-work`:** Full suite green + APK устанавливается и запускается
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | Status |
|---------|------|------|-------------|-----------|-------------------|--------|
| 1-01-01 | 01 | 1 | FOUND-01 | build | `flutter build apk --debug` | ✅ green |
| 1-01-02 | 01 | 1 | FOUND-02 | analyze | `flutter analyze --no-fatal-infos` | ✅ green |
| 1-02-01 | 02 | 1 | KEYS-01 | unit | `flutter test test/unit/secure_storage_test.dart` | ✅ green |
| 1-02-02 | 02 | 1 | KEYS-02 | unit | `flutter test test/unit/api_key_repository_test.dart` | ✅ green |
| 1-03-01 | 03 | 2 | IMPORT-01 | manual | Tap upload-card → пикер открывается | ⚠️ manual |
| 1-03-02 | 03 | 2 | IMPORT-02 | unit | `flutter test test/unit/file_validator_test.dart` | ✅ green |
| 1-04-01 | 04 | 2 | TRANS-03 | unit | `flutter test test/unit/groq_service_test.dart` | ✅ green |
| 1-04-02 | 04 | 2 | TRANS-07 | unit | `flutter test test/unit/groq_service_test.dart` | ✅ green |
| 1-04-03 | 04 | 2 | TRANS coord | unit | `flutter test test/unit/transcription_controller_test.dart` | ✅ green |
| 1-05-01 | 05 | 3 | OUT-02 | manual | Сохранение txt — path_provider требует платформы | ⚠️ manual |
| 1-05-02 | 05 | 3 | OUT-03 | widget | `flutter test test/widget/result_screen_test.dart` | ✅ green |
| 1-05-03 | 05 | 3 | OUT-05 | manual | APK install + запуск на устройстве | ⚠️ manual |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ manual*

---

## Wave 0 Requirements

- [x] `test/unit/secure_storage_test.dart` — FakeStorage для KEYS-01, KEYS-02 (5 кейсов)
- [x] `test/unit/api_key_repository_test.dart` — fake storage для KEYS-01 validation + KEYS-02 CRUD (8 кейсов)
- [x] `test/unit/file_validator_test.dart` — whitelist + size для IMPORT-02 (13 кейсов)
- [x] `test/unit/groq_service_test.dart` — MockClient для TRANS-03, TRANS-07 (8 кейсов)
- [x] `test/unit/transcription_controller_test.dart` — stub Groq + fake storage для TRANS coordinator (8 кейсов) ← *добавлено при аудите*
- [x] `test/widget/result_screen_test.dart` — Clipboard mock для OUT-03 (3 кейса)

> **IMPORT-01 (FilePickerService):** unit-тест невозможен — `FilePicker.platform` статический singleton
> без инъекции зависимости. Зафиксировано в 01-03-SUMMARY.md. Компенсация: ручная проверка на устройстве.

---

## Test Coverage Summary

| File | Требование | Кейсов | Тип |
|------|-----------|--------|-----|
| `test/unit/file_validator_test.dart` | IMPORT-02 | 13 | unit |
| `test/unit/api_key_repository_test.dart` | KEYS-01, KEYS-02 | 8 | unit |
| `test/unit/groq_service_test.dart` | TRANS-03, TRANS-07 | 8 | unit |
| `test/unit/secure_storage_test.dart` | KEYS-01, KEYS-02 | 5 | unit |
| `test/unit/transcription_controller_test.dart` | TRANS coord states | 8 | unit |
| `test/widget/result_screen_test.dart` | OUT-03, OUT-05 | 3 | widget |
| **Итого** | | **45** | |

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| APK устанавливается без падений | OUT-05, FOUND-01 | Требует физического устройства | `adb install build/app/outputs/flutter-apk/app-debug.apk` |
| Текст вставляется в Telegram | OUT-02 | Требует стороннего приложения | Нажать «Скопировать», открыть Telegram, вставить |
| API-ключ переживает перезапуск | KEYS-02 | Требует перезапуска приложения | Ввести ключ, убить приложение, открыть снова |
| Файловый пикер открывается | IMPORT-01 | FilePicker — static singleton, нет DI | Tap upload-card → системный picker → выбор .mp3 |
| txt сохраняется на диск | OUT-02 | path_provider — platform channel | ResultScreen → share/open txt; файл в app documents dir |

---

## Nyquist Gap Audit (2026-05-17)

**Выявленные пробелы при аудите:**

| Gap | Severity | Action |
|-----|----------|--------|
| `TranscriptionController` не имел ни одного теста | HIGH | ✅ Создан `transcription_controller_test.dart` (8 кейсов) |
| VALIDATION.md статусы не обновлены после выполнения фазы | MEDIUM | ✅ Обновлены все строки |
| Пути тестов в Wave 0 указывали на несуществующий `test/` root | LOW | ✅ Исправлено на `test/unit/` |
| `file_picker_test.dart` не создан (Wave 0 requirement) | LOW | ✅ Задокументировано как manual-only с обоснованием |

**Sampling continuity проверка:** Нет трёх подряд задач без автоматической верификации ✅

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify или manual-only с обоснованием
- [x] Sampling continuity: нет 3 подряд задач без автоматического verify
- [x] Wave 0 покрывает все MISSING references (IMPORT-01 задокументирован как static singleton)
- [x] Нет watch-mode флагов
- [x] Feedback latency < 60s
- [x] `nyquist_compliant: true` выставлен в frontmatter

**Approval:** ✅ Audited 2026-05-17
