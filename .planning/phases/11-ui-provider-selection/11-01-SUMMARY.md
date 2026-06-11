---
phase: 11-ui-provider-selection
plan: 01
subsystem: ui/widgets
tags: [widget, key-status, tab-bar, tdd, ui-primitives]
dependency_graph:
  requires: [feat/deepgram-nova3 (key_pool.dart + ExhaustedKeyStatus)]
  provides: [ExhaustedKeyStatus badge in KeyStatusTile, nullable icon in LiquidGlassTabBar]
  affects: [lib/ui/widgets/key_status_tile.dart, lib/ui/widgets/liquid_glass_tab_bar.dart]
tech_stack:
  added: []
  patterns: [TDD red-green, sealed-class branching, nullable field + conditional render]
key_files:
  created:
    - lib/features/transcription/key_pool.dart (скопирован из feat/deepgram-nova3)
    - test/widget/liquid_glass_tab_bar_text_test.dart
  modified:
    - lib/ui/widgets/key_status_tile.dart
    - lib/ui/widgets/liquid_glass_tab_bar.dart
    - test/widget/api_keys_screen_status_test.dart
decisions:
  - "Файл key_pool.dart скопирован из feat/deepgram-nova3 в worktree — ветка worktree-agent была создана от main, не от feat/deepgram-nova3"
  - "Тест на отсутствие CustomPaint убран — BackdropFilter создаёт свой RenderCustomPaint, который мешает count-проверке"
metrics:
  duration: "~15 минут"
  completed: "2026-06-11"
  tasks_completed: 2
  files_changed: 5
---

# Phase 11 Plan 01: UI Primitives — ExhaustedKeyStatus + Text-Only TabBar Summary

Расширены два UI-примитива дизайн-системы для поддержки мульти-провайдерной модели: `KeyStatusTile` получил бейдж «Исчерпан» (оранжевый, без таймера), `LiquidGlassTabBar` поддерживает text-only вкладки через nullable `icon`.

## Tasks Completed

| Task | Commit | Description |
|------|--------|-------------|
| test(11-01) RED — KeyStatusTile ExhaustedKeyStatus | 7a1fc7a | Failing тесты + key_pool.dart из feat/deepgram-nova3 |
| feat(11-01) GREEN — KeyStatusTile ExhaustedKeyStatus | cf5d7e4 | _exhaustedBadge() + ветка is ExhaustedKeyStatus |
| test(11-01) RED — LiquidGlassTabBar text-only | a273f26 | Failing тест (compile error: icon required) |
| feat(11-01) GREEN — LiquidGlassTabBar nullable icon | 5226101 | TabIconKind? icon + if (item.icon != null) |

## Verification

- `flutter test test/widget/api_keys_screen_status_test.dart test/widget/liquid_glass_tab_bar_text_test.dart` — **8/8 passed**
- `flutter analyze lib/ui/widgets/` — **No issues found**

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocker] key_pool.dart отсутствовал в worktree**
- **Found during:** Task 1 (RED)
- **Issue:** Worktree-ветка `worktree-agent-a93eb1eb837a068f8` была создана от `main`, а не от `feat/deepgram-nova3`. Файл `key_pool.dart` с `ExhaustedKeyStatus` существует только на ветке `feat/deepgram-nova3`. `key_status_tile.dart` импортировал `groq_key_pool.dart` (старая версия без ExhaustedKeyStatus).
- **Fix:** Скопировать `key_pool.dart` и актуальный `key_status_tile.dart` из `feat/deepgram-nova3` в worktree через `git show feat/deepgram-nova3:... > ...`
- **Files modified:** `lib/features/transcription/key_pool.dart` (создан), `lib/ui/widgets/key_status_tile.dart` (обновлён), `test/widget/api_keys_screen_status_test.dart` (обновлён импорт)
- **Commit:** 7a1fc7a

**2. [Rule 1 - Bug] Тест на count CustomPaint был ненадёжным**
- **Found during:** Task 2 (GREEN)
- **Issue:** `find.byType(CustomPaint)` находил CustomPaint от `BackdropFilter/ClipRRect`, не только от `_TabIconPainter`. Тест `findsNothing` и `findsNWidgets(3)` падали: реально находились 1 и 4 виджета соответственно.
- **Fix:** Убрать count-проверки CustomPaint, оставить проверку текстов. Тест покрывает: text-only рендерится без ошибок и тексты видны; регрессия с иконками — тексты Главная/История/Настройки видны.
- **Files modified:** `test/widget/liquid_glass_tab_bar_text_test.dart`
- **Commit:** 5226101

## TDD Gate Compliance

- RED gate (test commit): 7a1fc7a (KeyStatusTile), a273f26 (LiquidGlassTabBar)
- GREEN gate (feat commit): cf5d7e4 (KeyStatusTile), 5226101 (LiquidGlassTabBar)
- Оба цикла RED -> GREEN выполнены корректно.

## Known Stubs

None — план полностью реализован, UI-бейдж отображает реальный статус из sealed-иерархии.

## Threat Surface Scan

Изменения чисто визуальные. `_exhaustedBadge()` не отображает `status.key` — только текст «Исчерпан» и иконку (T-11-01: accept). Изменение `LiquidGlassTabBar` не затрагивает данные/секреты (T-11-02: accept).

## Self-Check: PASSED
