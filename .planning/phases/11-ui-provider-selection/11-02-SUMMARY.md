---
phase: 11-ui-provider-selection
plan: "02"
subsystem: ui-widgets
tags: [widget, dialog, parametrize, deepgram, groq, tdd]
dependency_graph:
  requires: []
  provides:
    - NoKeysDialog.show(context, title, bodyText, onOpenSettings)
  affects:
    - lib/ui/screens/home_screen.dart (вызов show без параметров — обратная совместимость)
    - plan 11-04 (Deepgram-диалог будет использовать параметры)
tech_stack:
  added: []
  patterns:
    - optional named params с Groq-дефолтами для обратной совместимости
    - onOpenSettings callback (Navigator.pop → callback)
key_files:
  created:
    - test/widget/no_keys_dialog_test.dart
  modified:
    - lib/ui/widgets/no_keys_dialog.dart
    - lib/ui/widgets/primary_button.dart
decisions:
  - "Дефолты Groq в двух местах: конструктор NoKeysDialog и static show() — обратная совместимость без параметров гарантирована"
  - "onOpenSettings вызывается ПОСЛЕ Navigator.pop(true) — диалог закрывается первым, потом навигация"
  - "Flexible вокруг Text в PrimaryButton — исправлен overflow в тестах (Ahem font + heading 20px bold)"
metrics:
  duration_minutes: 25
  completed_date: "2026-06-11"
  tasks_completed: 2
  files_changed: 3
---

# Phase 11 Plan 02: Параметризация NoKeysDialog Summary

**One-liner:** Параметризован NoKeysDialog (title/bodyText/onOpenSettings) с Groq-дефолтами для обратной совместимости; добавлены 3 widget-теста.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 (TDD RED) | Написать падающие тесты | 0cc9824 | test/widget/no_keys_dialog_test.dart (создан) |
| 1+2 (GREEN) | Параметризовать диалог + тесты зелёные | 5d06102 | no_keys_dialog.dart, primary_button.dart, no_keys_dialog_test.dart |

## What Was Built

`NoKeysDialog` параметризован тремя опциональными именованными параметрами:
- `title` (дефолт: `'Нужен ключ Groq'`)
- `bodyText` (дефолт: Groq-подсказка)
- `onOpenSettings` (дефолт: `null`, вызывается после `Navigator.pop(true)`)

Статический метод `show()` принимает те же параметры. Существующий вызов `NoKeysDialog.show(context)` без параметров работает без изменений.

## Verification Results

- `flutter test test/widget/no_keys_dialog_test.dart` — 3/3 green
- `flutter analyze lib/ui/widgets/no_keys_dialog.dart` — no issues
- `flutter test test/widget/home_screen_smoke_test.dart` — 2/2 green (регрессия)
- `flutter test test/widget/` — 13/13 all passed

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] RenderFlex overflow в PrimaryButton при тестировании диалога**
- **Found during:** Task 2 (widget test execution)
- **Issue:** `PrimaryButton` использует `Row(mainAxisSize: MainAxisSize.min)` с `Text` без `Flexible`. В тестовой среде Flutter использует Ahem шрифт (каждый символ = 1em × 1em), поэтому текст «Открыть настройки» (18 символов × 20px) занимает 360px, что превышает доступные ~312px внутри диалога.
- **Fix:** Обернул `Text` в `Flexible(child: Text(..., overflow: TextOverflow.ellipsis))` в `PrimaryButton`. Визуально на реальном устройстве (нормальный шрифт) изменение незаметно.
- **Files modified:** `lib/ui/widgets/primary_button.dart`
- **Commit:** 5d06102

## Known Stubs

None — диалог отображает реальные параметры, нет placeholder-значений.

## Threat Flags

None — план работает только с UI-текстом. Параметры `title`/`bodyText` — статические строки, `onOpenSettings` — навигационный callback без секретов.

## TDD Gate Compliance

- RED gate commit: `0cc9824` (test(11-02): add failing tests for parametrized NoKeysDialog)
- GREEN gate commit: `5d06102` (feat(11-02): параметризовать NoKeysDialog)
- Оба gate присутствуют в правильном порядке.

## Self-Check: PASSED

- `lib/ui/widgets/no_keys_dialog.dart` — FOUND
- `test/widget/no_keys_dialog_test.dart` — FOUND
- `lib/ui/widgets/primary_button.dart` — FOUND (deviation fix)
- Commit `0cc9824` — FOUND
- Commit `5d06102` — FOUND
- Acceptance criteria:
  - `final String title;` в no_keys_dialog.dart — FOUND
  - `final String bodyText;` — FOUND
  - `final VoidCallback? onOpenSettings;` — FOUND
  - `Text(title, ...)` вместо литерала — FOUND
  - `Text(bodyText, ...)` вместо литерала — FOUND
  - `onOpenSettings?.call()` — FOUND
  - Дефолты `'Нужен ключ Groq'` в конструкторе и show() — FOUND
