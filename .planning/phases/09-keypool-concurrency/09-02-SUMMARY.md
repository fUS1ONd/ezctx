---
phase: 09-keypool-concurrency
plan: "02"
subsystem: key-pool
tags: [refactor, tdd, key-pool, exhausted-keys, security]
dependency_graph:
  requires: ["09-01"]
  provides: ["KeyPool", "ExhaustedKeyStatus", "reportExhausted", "_isAlive"]
  affects: ["lib/main.dart", "lib/core/providers/service_providers.dart", "lib/ui/widgets/key_status_tile.dart"]
tech_stack:
  added: []
  patterns: ["sealed-class exhausted status", "fast-path AllKeysBlockedException", "_isAlive predicate"]
key_files:
  created: []
  modified:
    - lib/features/transcription/key_pool.dart
    - test/features/settings/key_pool_test.dart
    - lib/main.dart
    - lib/core/providers/service_providers.dart
    - lib/ui/widgets/key_status_tile.dart
    - test/widget/api_keys_screen_status_test.dart
decisions:
  - "groqKeyPoolProvider переменная сохранена по имени — переименование запланировано на фазу 10 (DI-проводка Deepgram)"
  - "AllKeysBlockedException edge-case R-04: быстрый путь _blockedUntil.isEmpty вместо 10-мин таймаута"
  - "ExhaustedKeyStatus имеет приоритет над BlockedKeyStatus в getStatuses/getStatusForKey"
  - "reportExhausted без _scheduleWakeup — ключ остаётся exhausted навсегда (до removeKey)"
metrics:
  duration: "~15 min"
  completed_date: "2026-06-09"
  tasks_completed: 2
  files_modified: 6
---

# Phase 09 Plan 02: KeyPool + ExhaustedKeyStatus Summary

GroqKeyPool переименован в провайдеро-независимый KeyPool с третьим sealed-статусом ExhaustedKeyStatus, методом reportExhausted (вечный вывод ключа), хелпером _isAlive, и критичным edge case — немедленный AllKeysBlockedException при всех exhausted + пустом _blockedUntil.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Переименовать GroqKeyPool → KeyPool (R-05 регрессия) | 744c6e3 | key_pool.dart, key_pool_test.dart, main.dart, service_providers.dart, key_status_tile.dart, api_keys_screen_status_test.dart |
| 2 RED | Failing-тесты R-01..R-04 (ExhaustedKeyStatus) | 39e931b | key_pool_test.dart |
| 2 GREEN | ExhaustedKeyStatus + reportExhausted + _isAlive + edge case | 97e8fa7 | key_pool.dart |

## Verification Results

- `flutter test test/features/settings/key_pool_test.dart` — 11/11 зелёных (7 регрессия R-05 + 4 новых R-01..R-04)
- `flutter analyze` — 0 ошибок по затронутым файлам (1 pre-existing info: fake_async transitive dependency)
- `GroqKeyPool` в затронутых файлах этого плана: 0 совпадений (контроллер/его тесты обновятся в 09-03)

## TDD Gate Compliance

- RED gate: commit `39e931b` — тесты R-01..R-04 добавлены, компиляция проваливается на ExhaustedKeyStatus/reportExhausted
- GREEN gate: commit `97e8fa7` — реализация, все 11 тестов зелёные
- REFACTOR gate: не требовался — код чист

## Deviations from Plan

None — план выполнен точно как написан.

## Threat Mitigations Applied

| Threat ID | Mitigation | Status |
|-----------|------------|--------|
| T-09-02-I | reportExhausted debugPrint маскирует ключ: `...${key.length > 4 ? key.substring(key.length - 4) : key}` | Применено |
| T-09-02-D | acquireKey быстрый путь `_blockedUntil.isEmpty` → немедленный AllKeysBlockedException | Применено (R-04) |
| T-09-02-I2 | AllKeysBlockedException.message статично, без интерполяции ключей | Применено |

## Known Stubs

None — все публичные API полностью реализованы.

## Threat Flags

None — новых trust boundaries не добавлено; все изменения в рамках существующего key_pool.

## Self-Check: PASSED
- lib/features/transcription/key_pool.dart — FOUND
- test/features/settings/key_pool_test.dart — FOUND
- commit 744c6e3 — FOUND (refactor: rename GroqKeyPool)
- commit 39e931b — FOUND (test: RED failing tests)
- commit 97e8fa7 — FOUND (feat: GREEN implementation)
