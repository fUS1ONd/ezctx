---
phase: 04-multi-key-pool
plan: "03"
subsystem: ui
tags: [key-status-tile, api-keys-screen, listenable-builder, timer-countdown, tdd]
dependency_graph:
  requires:
    - 04-01  # GroqKeyPool, KeyStatus, ActiveKeyStatus, BlockedKeyStatus
    - 04-02  # GroqKeyPool singleton в main.dart, wire-up контроллеров
  provides:
    - KeyStatusTile (виджет статуса ключа с обратным отсчётом)
    - ApiKeysScreen подписан на GroqKeyPool через ListenableBuilder
    - pool.addKey/removeKey синхронизированы с репозиторием
  affects:
    - lib/ui/app.dart
tech_stack:
  added: []
  patterns:
    - StatefulWidget + Timer.periodic для обратного отсчёта
    - dispose() отменяет Timer (утечка памяти prevention)
    - ListenableBuilder для реактивного UI без setState на всём экране
    - didUpdateWidget пересоздаёт Timer при смене типа статуса
key_files:
  created:
    - lib/ui/widgets/key_status_tile.dart
    - test/widget/api_keys_screen_status_test.dart
  modified:
    - lib/ui/screens/api_keys_screen.dart
    - lib/ui/app.dart
decisions:
  - "KeyStatusTile использует DateTime.now() — не clock.now(), т.к. UI-таймер не тестируется с fake_async"
  - "ListenableBuilder обёртывает только Column карточек — не весь Scaffold; экономит перерисовки"
  - "pool.addKey вызывается после repository.addKey (репозиторий — master, пул дополняет статусами)"
metrics:
  duration_seconds: 480
  completed_date: "2026-05-18"
  tasks_completed: 2
  files_changed: 4
---

# Phase 04 Plan 03: Wave 3 — UI статуса ключей (KeyStatusTile + ApiKeysScreen) Summary

**One-liner:** KeyStatusTile с Timer.periodic обратным отсчётом и ApiKeysScreen, реактивно подписанная на GroqKeyPool через ListenableBuilder — пользователь видит статус каждого ключа в реальном времени.

## Что сделано

### Task 1: KeyStatusTile — RED → GREEN (TDD)

**Коммиты:** 6a077ff (test/RED) → 374608e (feat/GREEN)

**Файлы:** `lib/ui/widgets/key_status_tile.dart`, `test/widget/api_keys_screen_status_test.dart`

- `KeyStatusTile(status: ActiveKeyStatus)` → зелёный индикатор + текст "Активен"
- `KeyStatusTile(status: BlockedKeyStatus(blockedUntil: now + 90s))` → красный + "До 00:01:30"
- `Timer.periodic(1s)` запускается в `initState()` только для `BlockedKeyStatus`
- `didUpdateWidget` пересоздаёт таймер при смене типа статуса (Active↔Blocked)
- `dispose()` отменяет `_timer` — нет утечек (T-04-08 threat mitigation)
- Если `blockedUntil.difference(DateTime.now()).isNegative` → отображается как активный
- 3/3 widget-тестов зелёные

### Task 2: Обновление ApiKeysScreen (5a85d16)

**Файлы:** `lib/ui/screens/api_keys_screen.dart`, `lib/ui/app.dart`

- `ApiKeysScreen` принимает `required GroqKeyPool pool`
- `_buildKeysList` обёрнут в `ListenableBuilder(listenable: widget.pool)`
- `KeyStatusTile(status: widget.pool.getStatusForKey(key.raw))` добавлен в карточку ключа
- `_onAddPressed`: после `repository.addKey(rawKey)` → `widget.pool.addKey(rawKey)`
- `_confirmDelete`: после `repository.removeKey(key.raw)` → `widget.pool.removeKey(key.raw)`
- `app.dart`: `ApiKeysScreen(pool: groqKeyPool)` — pool передаётся при навигации
- `launchUrl` для `console.groq.com/keys` сохранён без регрессий (KEYS-04)

## Commits

| Задача | Коммит | Тип |
|--------|--------|-----|
| 1 RED: failing widget-тесты | 6a077ff | test |
| 1 GREEN: KeyStatusTile | 374608e | feat |
| 2: ApiKeysScreen + app.dart | 5a85d16 | feat |

## Verification

```
flutter analyze lib/ → 7 info (pre-existing в result_screen.dart, не в наших файлах)
flutter analyze lib/ui/widgets/key_status_tile.dart → No issues found
flutter analyze lib/ui/screens/api_keys_screen.dart → No issues found
flutter test test/widget/api_keys_screen_status_test.dart → 3 passed
grep -c 'ListenableBuilder' api_keys_screen.dart → 3
grep -c 'KeyStatusTile' api_keys_screen.dart → 1
grep -c 'cancel' key_status_tile.dart → 2
grep -c 'pool.addKey|pool.removeKey' api_keys_screen.dart → 2
```

## Deviations from Plan

None — план выполнен точно по спецификации.

## TDD Gate Compliance

- RED commit: 6a077ff (test(04-03): добавить failing widget-тесты KeyStatusTile)
- GREEN commit: 374608e (feat(04-03): реализовать KeyStatusTile с Timer.periodic)
- Оба gate-коммита существуют в правильном порядке.

## Known Stubs

None — KeyStatusTile и ListenableBuilder полностью функциональны.

## Threat Flags

Нет новых threat surface сверх задокументированных в плане (T-04-07, T-04-08 обработаны).

## Self-Check: PASSED

- FOUND: lib/ui/widgets/key_status_tile.dart
- FOUND: test/widget/api_keys_screen_status_test.dart
- FOUND: lib/ui/screens/api_keys_screen.dart (modified)
- FOUND: lib/ui/app.dart (modified)
- Коммит 6a077ff: EXISTS
- Коммит 374608e: EXISTS
- Коммит 5a85d16: EXISTS
