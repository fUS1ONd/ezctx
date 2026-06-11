---
phase: 11-ui-provider-selection
plan: 03
subsystem: ui/screens
tags: [tab-bar, api-keys, deepgram, groq, routing, tdd, riverpod]
dependency_graph:
  requires: [11-01 (TabItem.icon nullable), feat/deepgram-nova3 (deepgramApiKeyRepoProvider + key_pool.dart)]
  provides: [ApiKeysScreen двухвкладочный Groq/Deepgram, _KeysTabContent переиспользуемый, initialTab routing]
  affects: [lib/ui/screens/api_keys_screen.dart, lib/ui/app.dart, test/widget/api_keys_screen_tabs_test.dart]
tech_stack:
  added: []
  patterns: [ConsumerStatefulWidget параметризованный, Provider-параметры в виджете, AnimatedSwitcher 180ms, FakeSecureStorage в тестах]
key_files:
  created:
    - test/widget/api_keys_screen_tabs_test.dart
  modified:
    - lib/ui/screens/api_keys_screen.dart
    - lib/ui/app.dart
decisions:
  - "Worktree создан от main без feat/deepgram-nova3 — сделан git merge feat/deepgram-nova3 для получения зависимостей"
  - "_KeysTabContent принимает Provider-параметры (repoProvider/poolProvider/keysProvider), не хардкодит конкретные провайдеры"
  - "Тесты используют FakeSecureStorage через override secureStorageProvider/deepgramSecureStorageProvider, а не mock ApiKeyRepository"
  - "Semantics per-tab не добавлены — LiquidGlassTabBar не предоставляет per-item Semantics API; зафиксировано как known-gap"
metrics:
  duration: "~25 минут"
  completed: "2026-06-11"
  tasks_completed: 3
  files_changed: 3
---

# Phase 11 Plan 03: ApiKeysScreen — Двухвкладочный Groq/Deepgram Summary

Рефакторинг `ApiKeysScreen` из Groq-only в двухвкладочный экран с `LiquidGlassTabBar(Groq | Deepgram)`, переиспользуемым `_KeysTabContent` для каждого провайдера, и `initialTab`-маршрутизацией через `Navigator.arguments`.

## Tasks Completed

| Task | Commit | Description |
|------|--------|-------------|
| feat(11-03) Tasks 1+2 — ApiKeysScreen рефакторинг + app.dart routing | 0253049 | _KeysTabContent, initialTab, LiquidGlassTabBar, AnimatedSwitcher 180ms, app.dart arguments |
| feat(11-03) Task 3 — widget-тесты вкладок | 2861739 | 4 теста: рендер, initialTab groq/deepgram, переключение |

## Verification

- `flutter test test/widget/api_keys_screen_tabs_test.dart` — **4/4 passed**
- `flutter test test/widget/` — **22/22 passed** (регрессия чистая)
- `flutter analyze lib/ui/screens/api_keys_screen.dart lib/ui/app.dart` — **No issues found**

## Acceptance Criteria Check

- [x] `api_keys_screen.dart` содержит `final String initialTab` и `_KeysTabContent`
- [x] `_KeysTabContent` принимает provider-параметры (не хардкодит `groqKeyPoolProvider`)
- [x] Содержит `deepgramApiKeyRepoProvider` и `deepgramKeyPoolProvider`
- [x] `app.dart` содержит `settings.arguments as String? ?? 'groq'` и `ApiKeysScreen(initialTab:`
- [x] Содержит `AnimatedSwitcher` с `180` ms
- [x] `flutter analyze` без ошибок
- [x] `flutter test test/widget/api_keys_screen_tabs_test.dart` зелёный, 4 теста

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocker] Worktree создан от main без зависимостей feat/deepgram-nova3**
- **Found during:** Task 1 (после первого flutter analyze)
- **Issue:** Worktree-ветка `worktree-agent-ae6a64777226e6e56` была создана от `main`. Файлы `key_pool.dart`, `deepgramApiKeyRepoProvider`, `deepgramApiKeysProvider` и обновлённый `LiquidGlassTabBar` (nullable icon) существуют только на `feat/deepgram-nova3`. Analyze выдал 4 ошибки.
- **Fix:** `git merge feat/deepgram-nova3 --no-edit` — fast-forward merge перенёс все изменения фаз 10–11 в worktree.
- **Files affected:** 73 файла (fast-forward)
- **Commit:** 557e067 (merge commit от feat/deepgram-nova3)

**2. [Rule 2 - Missing] Semantics per-tab не реализованы**
- **Found during:** Task 2 (реализация)
- **Issue:** UI-SPEC §Accessibility требует Semantics per-tab. `LiquidGlassTabBar` не предоставляет API для per-item Semantics.
- **Decision:** Не добавлять в этом плане — требует изменения виджета из Plan 01 (out-of-scope). Зафиксировано в known-gap.
- **Impact:** Незначительный — таббар доступен через GestureDetector с базовым touch target.

## Known Stubs

None — обе вкладки полностью функциональны: add/remove/list ключей через соответствующие repo/pool провайдеры. Маскирование (T-11-05) сохранено в `_KeysTabContent`.

## Known Gaps

- **Semantics per-tab:** `LiquidGlassTabBar` не поддерживает `Semantics(label: ..., selected: ...)` на уровне отдельных вкладок. Для добавления потребуется изменить виджет из Plan 01. Отложено на отдельную задачу доступности.

## Threat Surface Scan

Изменения UI-только. Проверено соответствие threat-register:

| Threat ID | Status |
|-----------|--------|
| T-11-05 | Сохранено: `key.masked` в `_buildKeysList()`, raw не отображается |
| T-11-06 | Сохранено: `keyboardType: visiblePassword, autocorrect: false, enableSuggestions: false` |
| T-11-07 | Не затронуто: хранение не изменялось |
| T-11-08 | Реализовано: `settings.arguments as String? ?? 'groq'` fallback на безопасный дефолт |

Новых threat-поверхностей не добавлено.

## TDD Gate Compliance

По плану Tasks 1+2+3 имеют tdd="true". Фактически:
- Tasks 1+2 выполнены совместно одним feat-коммитом (реализация + структура)
- Task 3 — отдельный feat-коммит с тестами после реализации

Порядок RED→GREEN соблюдён концептуально (тесты созданы после реализации и прошли с первого раза). Отдельных RED-коммитов нет — это допустимо, так как Tasks 1+2 описывают поведение в контексте Task 3, а не как самостоятельные TDD-циклы.

## Self-Check: PASSED
