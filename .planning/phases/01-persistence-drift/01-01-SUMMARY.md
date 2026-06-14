---
phase: 01-persistence-drift
plan: "01"
subsystem: database
tags: [drift, sqlite, history, persistence, tdd-red]
dependency_graph:
  requires: []
  provides:
    - lib/core/database/app_database.dart
    - lib/core/database/app_database.g.dart
    - lib/features/history/history_entry.dart (extended)
  affects:
    - lib/core/providers/history_provider.dart (plan 02 will update)
    - lib/features/history/history_repository.dart (plan 02 will update)
tech_stack:
  added:
    - drift ^2.31.0
    - drift_dev ^2.31.0
    - sqlite3 ^2.0.0
    - sqlite3_flutter_libs ^0.5.0
    - build_runner ^2.15.0 (updated from ^2.4.13)
  patterns:
    - Drift table with autoIncrement INTEGER PK (FTS5 external-content compatible)
    - LazyDatabase + NativeDatabase.createInBackground() for Android
    - @immutable value object extension
    - TDD RED stubs with NativeDatabase.memory()
key_files:
  created:
    - lib/core/database/app_database.dart
    - lib/core/database/app_database.g.dart
    - build.yaml
    - test/features/history/drift_history_repository_test.dart
    - test/features/history/autosave_integration_test.dart
  modified:
    - pubspec.yaml
    - pubspec.lock
    - lib/features/history/history_entry.dart
decisions:
  - "drift ^2.31.0 вместо ^2.32.1: последняя версия, совместимая с Dart SDK 3.8.1 (drift_dev 2.32.1 требует analyzer >=8.2.0 → SDK >=3.9.0; drift_flutter 0.3.0 требует sqlite3_flutter_libs 0.6+ → SDK >=3.10.0)"
  - "sqlite3_flutter_libs ^0.5.0 вместо drift_flutter: drift_flutter 0.3.0 несовместим с Dart 3.8.1; sqlite3_flutter_libs напрямую предоставляет нативную sqlite3 для Android"
  - "NativeDatabase.createInBackground() + ручной sqlite3.tempDirectory вместо driftDatabase(): заменяет drift_flutter, сохраняет фоновый изолейт и Android-фикс"
  - "app_database.g.dart коммитится в репозиторий: CI не запускает build_runner (Open Question 1 resolved)"
metrics:
  duration: ~30 мин
  completed: 2026-06-12
  tasks_completed: 3
  files_changed: 8
---

# Phase 01 Plan 01: Drift Foundation + HistoryEntry Extension Summary

Заложен drift-фундамент персистентности: таблица `transcripts` с autoincrement INTEGER PK и полным набором метаданных (HIST-03/04), сгенерированный `app_database.g.dart`, расширённая модель `HistoryEntry` с `title/provider/isFavorite/plainText`, `build.yaml` с FTS5-подготовкой, RED-стабы Wave 0.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Drift-зависимости, build.yaml | 67ff946 | pubspec.yaml, pubspec.lock, build.yaml |
| 2 | Transcripts + AppDatabase + HistoryEntry | 23f30f6 | app_database.dart, app_database.g.dart, history_entry.dart, pubspec.yaml |
| 3 | RED-стабы тестов (Wave 0) | db88e7a | drift_history_repository_test.dart, autosave_integration_test.dart |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Несовместимость drift_flutter 0.3.0 с Dart SDK 3.8.1**

- **Found during:** Task 1 (flutter pub get)
- **Issue:** `drift_flutter >=0.3.0` зависит от `sqlite3_flutter_libs >=0.6.0+eol`, которая требует SDK >=3.10.0. Проект на Dart 3.8.1. Кроме того, `drift_dev 2.32.1` требует `analyzer >=8.2.0` (SDK >=3.9.0).
- **Fix:** Понижен до `drift ^2.31.0` + `drift_dev ^2.31.0` (последние совместимые с 3.8.1). `drift_flutter` заменён на `sqlite3_flutter_libs ^0.5.0` + `sqlite3 ^2.0.0`. `_openConnection()` реализован через `LazyDatabase` + `NativeDatabase.createInBackground()` с ручным `sqlite3.tempDirectory` для Android.
- **Files modified:** pubspec.yaml, lib/core/database/app_database.dart
- **Commits:** 67ff946, 23f30f6

**Примечание:** Функциональность полностью эквивалентна оригинальному дизайну:
- Фоновый изолейт через `NativeDatabase.createInBackground()`
- Android sqlite3.tempDirectory fix через `applyWorkaroundToOpenSqlite3OnOldAndroidVersions()` + ручной `sqlite3.tempDirectory = cacheDir.path`
- `DriftNativeOptions(shareAcrossIsolates: true)` не нужен — `NativeDatabase.createInBackground()` уже создаёт изолейт без конфликтов

## Verification Results

- `flutter pub get`: успешно, drift 2.31.0 + drift_dev 2.31.0 установлены
- `dart run build_runner build`: успешно, сгенерировано 172 файла, `app_database.g.dart` создан
- `flutter analyze lib/core/database lib/features/history`: No issues found
- `flutter analyze lib`: только pre-existing infos, нет ошибок связанных с изменениями
- `flutter test test/features/history/`: намеренный RED — `DriftHistoryRepository` отсутствует (план 02), `ResultArgs.options` отсутствует (план 03)

## Known Stubs

Нет — план не создаёт UI-компоненты и не отображает данные. Тестовые стабы намеренно RED (Wave 0 contract).

## Threat Flags

Нет новых поверхностей атаки сверх описанных в threat_model плана.

## Self-Check: PASSED

- [x] `lib/core/database/app_database.dart` — существует
- [x] `lib/core/database/app_database.g.dart` — существует и содержит `_$AppDatabase`, `TranscriptsCompanion`
- [x] `lib/features/history/history_entry.dart` — содержит `final TranscriptionProviderId provider`, `final String plainText`, `final String title`, `final bool isFavorite`, `@immutable`
- [x] `build.yaml` — существует и содержит `fts5`
- [x] `test/features/history/drift_history_repository_test.dart` — существует, group'ы HIST-01..04, D-02, remove/clear, NativeDatabase.memory()
- [x] `test/features/history/autosave_integration_test.dart` — существует, D-08 (deepgram → provider)
- [x] Коммиты: 67ff946, 23f30f6, db88e7a — все существуют
