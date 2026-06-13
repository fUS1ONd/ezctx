---
phase: 04-ui-ux-detail
plan: 01
subsystem: ui
tags: [flutter, dart, riverpod, glassmorphism, history, design-tokens]

# Dependency graph
requires:
  - phase: 03-detail-actions
    provides: HistoryEntry модель (title/provider/isFavorite/snippet), HistoryRepository.update(), history_actions_test.dart паттерн
provides:
  - "languageLabel()/providerLabel() — чистые функции нормализации лейблов для language/provider пиллов"
  - "showGlassConfirmDialog() — стеклянный confirm-диалог (GlassCard, не AlertDialog)"
  - "test/widget/history_slidable_test.dart — Wave 0 RED-стаб для свайп-избранного, контракт для плана 04-02"
affects: [04-02-history-screen, 04-03-detail-screen]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Чистые dart:core утилиты без Flutter-импортов для отображательного слоя (history_label_utils.dart)"
    - "showDialog<bool> + GlassCard(deep:true) вместо AlertDialog для confirm-диалогов"

key-files:
  created:
    - lib/features/history/history_label_utils.dart
    - lib/ui/widgets/glass_confirm_dialog.dart
    - test/features/history/history_label_utils_test.dart
    - test/widget/history_slidable_test.dart
  modified: []

key-decisions:
  - "languageLabel/providerLabel — чистые функции без сайд-эффектов, сырое значение в БД не меняется (D-04/D-06)"
  - "showGlassConfirmDialog использует showDialog (не showGeneralDialog как NoKeysDialog) — проще, barrierDismissible по умолчанию true"

patterns-established:
  - "history_label_utils.dart: пара normalize-функций с guard на пустую строку -> '—', fallback на капитализацию для неизвестных значений"
  - "glass_confirm_dialog.dart: Dialog(transparent) + GlassCard(deep:true) + Column(title/body/Row(cancel,confirm)) — конфирм-диалог проекта"

requirements-completed: [BRWS-01, ACT-04, ACT-02]

# Metrics
duration: 12min
completed: 2026-06-13
---

# Phase 04 Plan 01: Wave 0 фундамент полировки (label utils + glass confirm + slidable стаб) Summary

**Чистые функции `languageLabel`/`providerLabel` для бейджей истории, стеклянный `showGlassConfirmDialog` на базе `GlassCard`, и Wave 0 RED-тест `history_slidable_test.dart` как контракт для плана 04-02.**

## Performance

- **Duration:** 12 min
- **Started:** 2026-06-13T09:21:00Z
- **Completed:** 2026-06-13T09:33:00Z
- **Tasks:** 3
- **Files modified:** 4 (все новые)

## Accomplishments
- `languageLabel('en-US')` → `'EN'`, `languageLabel('')` → `'—'`, `languageLabel('auto')` → `'AUTO'` — 4 кейса, все зелёные
- `providerLabel('groq')` → `'Groq'`, `providerLabel('whisper')` → `'Whisper'` (fallback-капитализация), `providerLabel('')` → `'—'` — 4 кейса, все зелёные
- `showGlassConfirmDialog` рендерит `GlassCard(deep:true)` внутри `Dialog(transparent)`, без `AlertDialog`, `barrierDismissible: true`, цвет confirm-кнопки переключается между `palette.bad`/`palette.accent` через флаг `destructive`
- Wave 0 widget-тест `history_slidable_test.dart` скопирован с инфраструктурой `_StubRepo`/`_FixedFilterNotifier`/`_buildApp`/`_makeEntry` из `history_actions_test.dart`, содержит `swipe_right_toggles_favorite` — компилируется, корректно RED (виджет `_SlidableTile` появится в плане 04-02)

## Task Commits

Each task was committed atomically:

1. **Task 1: history_label_utils.dart + unit-тесты (RED→GREEN)** — `bb0c54a` (test, RED) → `43a5850` (feat, GREEN)
2. **Task 2: glass_confirm_dialog.dart (стеклянный confirm)** — `cf30a13` (feat)
3. **Task 3: Wave 0 тест-стаб history_slidable_test.dart** — `a1dd76b` (test, RED — намеренно)

**Plan metadata:** committed alongside this SUMMARY (worktree mode — STATE.md/ROADMAP.md обновляет оркестратор)

_Note: Task 1 — полный RED→GREEN цикл TDD (2 коммита). Task 3 — намеренно остаётся RED до плана 04-02._

## Files Created/Modified
- `lib/features/history/history_label_utils.dart` - две чистые dart:core функции `languageLabel`/`providerLabel` с defensive fallback
- `lib/ui/widgets/glass_confirm_dialog.dart` - `showGlassConfirmDialog()` на `GlassCard(deep:true)`, замена `AlertDialog`
- `test/features/history/history_label_utils_test.dart` - 8 unit-тестов (4 на languageLabel, 4 на providerLabel), все зелёные
- `test/widget/history_slidable_test.dart` - Wave 0 контракт-тест `swipe_right_toggles_favorite`, RED (по дизайну)

## Decisions Made
- `showGlassConfirmDialog` реализован через `showDialog<bool>` (не `showGeneralDialog`, как у `NoKeysDialog`) — проще и `barrierDismissible: true` доступен из коробки
- Doc-комментарий `glass_confirm_dialog.dart` переформулирован без литерала `AlertDialog`, чтобы source-assertion из acceptance criteria («Source НЕ содержит `AlertDialog`») проходил корректно — упоминание в комментарии заменено на «стандартного Material3-диалога»

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - все 3 задачи прошли по плану. RED-статус `history_slidable_test.dart` (Task 3) — ожидаемое, документированное в плане поведение, не проблема.

## TDD Gate Compliance

Task 1 (tdd="true"): RED-коммит `bb0c54a` (test) присутствует ДО GREEN-коммита `43a5850` (feat) — gate sequence соблюдён, REFACTOR не требовался (реализация минимальна и чиста с первого прохода).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Контракты для планов 04-02 (history_screen) и 04-03 (detail_screen) готовы:
  `languageLabel`/`providerLabel` из `history_label_utils.dart`, `showGlassConfirmDialog` из `glass_confirm_dialog.dart`.
- `test/widget/history_slidable_test.dart` — RED, ожидает реализацию `_SlidableTile` в плане 04-02 (свайп вправо → toggle ★ через `repo.update`, свайп влево → reveal удаления).
- Существующие экраны (`history_screen.dart`, `detail_screen.dart`) не тронуты — нулевой риск регрессий.

---
*Phase: 04-ui-ux-detail*
*Completed: 2026-06-13*

## Self-Check: PASSED

All created files found on disk; all 4 task commit hashes (bb0c54a, 43a5850, cf30a13, a1dd76b) verified in git log.
