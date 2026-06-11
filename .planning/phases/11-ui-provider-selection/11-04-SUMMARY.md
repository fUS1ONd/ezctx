---
phase: 11-ui-provider-selection
plan: "04"
subsystem: settings-ui
tags: [settings, multi-provider, nova3, status-card, pluralization, tdd]
dependency_graph:
  requires: [11-02, 11-03]
  provides: [nova3-in-picker, multi-provider-status-card, no-keys-deepgram-dialog, api-keys-tab-nav]
  affects: [lib/ui/screens/settings_screen.dart]
tech_stack:
  added: []
  patterns: [ListenableBuilder, ValueKey-provider, top-level-pluralize, TDD-red-green]
key_files:
  created:
    - test/unit/key_count_pluralization_test.dart
    - test/widget/settings_screen_status_card_test.dart
    - test/widget/settings_screen_model_picker_test.dart
  modified:
    - lib/ui/screens/settings_screen.dart
decisions:
  - "pluralizeKeys извлечена в top-level функцию файла settings_screen.dart для прямого импорта unit-тестом"
  - "StatusCard обёрнута в ListenableBuilder с key: ValueKey(provider) — пересоздание виджета при смене провайдера (Pitfall 3)"
  - "_keyCountLabel удалена из _SettingsScreenState как дублирующая pluralizeKeys"
  - "Иконка StatusCard заменена с буквы G на Icon(Icons.vpn_key_rounded) — провайдеро-нейтральная"
metrics:
  duration: "~25 min"
  completed: "2026-06-11"
  tasks_completed: 3
  files_changed: 4
---

# Phase 11 Plan 04: SettingsScreen мульти-провайдерная доработка Summary

**One-liner:** Мультипровайдерный SettingsScreen — nova3 в пикере, ListenableBuilder StatusCard с форматом «{модель} · {провайдер} · {N ключей}», NoKeysDialog Deepgram, tab-навигация API-ключей.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 (RED) | Failing unit-тест pluralizeKeys | 16383ea | test/unit/key_count_pluralization_test.dart |
| 1 (GREEN) | nova3 в пикере + NoKeysDialog + pluralizeKeys | a61fef6 | lib/ui/screens/settings_screen.dart |
| 2 | Мультипровайдерная StatusCard + tab-навигация | a61fef6 | lib/ui/screens/settings_screen.dart (в одном коммите с Task 1) |
| 3 | Widget-тесты StatusCard и пикера | fd914a3 | test/widget/settings_screen_status_card_test.dart, test/widget/settings_screen_model_picker_test.dart |

## What Was Built

### `lib/ui/screens/settings_screen.dart`

**top-level `pluralizeKeys(int n)`**
- Экспортируется для unit-тестирования
- Русская плюрализация: 0 → «Нет ключей», 1/21 → «N ключ», 2-4/22-24 → «N ключа», остальное → «N ключей»
- Исключения mod100 для 11-14/111-114

**Убран фильтр nova3 (D-14)**
- `options: TranscriptionModel.values` — без `.where((m) => m != TranscriptionModel.nova3)`
- Удалён комментарий «nova3 скрыта до Phase 10»

**NoKeysDialog Deepgram (D-05..D-07)**
- onChanged nova3 → `ref.read(deepgramKeyPoolProvider).aliveKeyCount == 0` → `NoKeysDialog.show(title: 'Нужен ключ Deepgram', ...)`
- Кнопка «Открыть настройки» → `Navigator.pushNamed(routeApiKeys, arguments: 'deepgram')`

**ListenableBuilder StatusCard (D-11..D-13)**
- `activePool = model.provider == deepgram ? deepgramPool : groqPool`
- `ListenableBuilder(key: ValueKey(model.provider), listenable: activePool, ...)`
- Формат строки: «{модель} · {провайдер} · {N ключей} · Подключено» или «Нет ключей»
- Индикатор-кружок: `palette.good` при keyCount>0, иначе `palette.bad`

**_Row «API-ключи» tab-навигация (D-09)**
- `final tab = model.provider == deepgram ? 'deepgram' : 'groq'`
- `Navigator.pushNamed(routeApiKeys, arguments: tab)`
- detail: `pluralizeKeys(activePool.aliveKeyCount)`

### Тесты

**`test/unit/key_count_pluralization_test.dart`** — 10 unit-тестов edge-кейсов: 0, 1, 2, 4, 5, 11, 21, 22, 25, 111.

**`test/widget/settings_screen_status_card_test.dart`** — 3 теста:
- Whisper + 1 Groq ключ → «Groq · 1 ключ · Подключено»
- Nova-3 + 0 Deepgram ключей → «Nova-3 · Deepgram · Нет ключей»
- Nova-3 + 2 Deepgram ключа → «2 ключа · Подключено»

**`test/widget/settings_screen_model_picker_test.dart`** — 1 тест: Nova-3 видна в пикере.

## Decisions Made

1. `pluralizeKeys` — top-level функция в том же файле, не helper-файл: минимальная связность, прямой импорт из unit-теста.
2. `ListenableBuilder` с `key: ValueKey(model.provider)` — виджет пересоздаётся при смене модели на другой провайдер (Pitfall 3 из RESEARCH.md), чтобы `listenable` всегда указывал на актуальный пул.
3. Task 1 и Task 2 совмещены в одном коммите (a61fef6) — изменения в одном файле, оба acceptance-criteria проверены.
4. Иконка в StatusCard: `Icons.vpn_key_rounded` вместо буквы «G» — провайдеро-нейтральная без нарушения формата строки.

## Deviations from Plan

### Auto-merged Tasks 1+2

**Причина:** Task 1 и Task 2 оба модифицируют только `settings_screen.dart`. Разделение привело бы к промежуточному нерабочему состоянию (Task 1 без StatusCard обновления). Все acceptance-criteria обоих тасков проверены в одном коммите.

**Влияние:** Нулевое — коммит содержит полную реализацию обоих тасков.

## Known Stubs

Нет — все данные передаются из реальных `KeyPool.aliveKeyCount` через `ListenableBuilder`. Стабов нет.

## Threat Flags

Нет новой поверхности атаки. T-11-11 (аргумент 'groq'/'deepgram') митигирован: передаётся строковый литерал, app.dart (Plan 03) валидирует через `as String? ?? 'groq'`.

## Self-Check: PASSED

- [x] `lib/ui/screens/settings_screen.dart` существует и содержит `pluralizeKeys`, `ListenableBuilder`, `options: TranscriptionModel.values`, `arguments: tab`
- [x] `test/unit/key_count_pluralization_test.dart` — 10 тестов зелёных
- [x] `test/widget/settings_screen_status_card_test.dart` — 3 теста зелёных
- [x] `test/widget/settings_screen_model_picker_test.dart` — 1 тест зелёный
- [x] `flutter analyze lib/ui/screens/settings_screen.dart` — No issues found
- [x] Коммиты: 16383ea (RED), a61fef6 (GREEN/Task1+2), fd914a3 (Task3)
