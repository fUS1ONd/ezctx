---
phase: 07-provider-abstraction
plan: 01
subsystem: transcription
tags: [dart, flutter, enum, data-model, migration, settings]

# Dependency graph
requires: []
provides:
  - "enum TranscriptionProviderId { groq, deepgram }"
  - "enum TranscriptionModel(provider, apiValue) с членами whisperLargeV3/whisperTurbo/nova3"
  - "TranscriptionOptions, привязанная к TranscriptionModel, с миграцией legacy-хранилища (largeV3/turbo)"
  - "settings_screen, компилируемый и работающий с новой моделью (включая лейбл 'Nova-3')"
  - "тест миграции transcription_options_migration_test.dart"
affects: [07-02-provider-interface, 10-deepgram-provider, 11-ui-provider-selection]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Провайдер выводится из модели через TranscriptionModel.provider — не хранится отдельным полем"
    - "Миграция legacy-строк хранилища через словарь алиасов (_legacyModelAliases), проверяемый перед поиском по новым именам enum"

key-files:
  created:
    - test/features/settings/transcription_options_migration_test.dart
  modified:
    - lib/features/transcription/transcription_options.dart
    - lib/ui/screens/settings_screen.dart

key-decisions:
  - "WhisperModel удалён полностью и заменён TranscriptionModel — провайдер всегда выводится из выбранной модели, отдельного поля провайдера в TranscriptionOptions нет"
  - "Миграция legacy-значений ('largeV3'/'turbo') реализована через явный словарь _legacyModelAliases, проверяемый ПЕРЕД поиском по новым именам enum — гарантирует отсутствие исключений на старом хранилище"
  - "settings_screen обновлён минимально: только смена типа enum и добавление лейбла 'Nova-3' в exhaustive switch — без изменения вёрстки/UI-логики (фильтрация моделей по доступности — отдельная UI-фаза)"

patterns-established:
  - "Алиасы legacy-сериализации хранить отдельной const Map рядом с моделью данных, проверять её первой в fromJson"

requirements-completed: []

# Metrics
duration: ~25min
completed: 2026-06-08
---

# Phase 07 Plan 01: Расширение модели данных под мульти-провайдерную архитектуру Summary

**Заменили `WhisperModel` на провайдеро-привязанный `TranscriptionModel(provider, apiValue)` с безопасной миграцией старого хранилища `transcription_options_v1`, не сломав ни одного из 140 существующих тестов.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-06-08T19:43:00Z (примерно)
- **Completed:** 2026-06-08T20:06:00Z
- **Tasks:** 3/3
- **Files modified:** 3 (2 изменённых, 1 создан)

## Accomplishments
- Введены `enum TranscriptionProviderId { groq, deepgram }` и `enum TranscriptionModel(provider, apiValue)` с членами `whisperLargeV3`, `whisperTurbo`, `nova3` — провайдер выводится из модели без отдельного поля.
- `TranscriptionOptions.fromJson` мигрирует legacy-строки старого хранилища (`"largeV3"`/`"turbo"`) в новые члены enum без исключений; новый формат и мусорные значения тоже обрабатываются безопасно (fallback на `whisperLargeV3`).
- `settings_screen.dart` переведён на `TranscriptionModel` с добавлением лейбла `'Nova-3'` — exhaustive switch компилируется, UI-логика не тронута.
- Добавлен тест миграции (9 кейсов: legacy→new, новый формат, мусор→fallback, round-trip, свойства provider/apiValue) — все зелёные.
- Полный набор `flutter test` (140 тестов) остаётся зелёным; `flutter analyze` не выдаёт новых ошибок/предупреждений в затронутых файлах.

## Task Commits

Each task was committed atomically:

1. **Task 1: Заменить WhisperModel на TranscriptionModel + TranscriptionProviderId с миграцией** - `a3ca0f1` (feat)
2. **Task 2: Обновить settings_screen под новый enum** - `5aa6806` (feat)
3. **Task 3: Тест миграции TranscriptionOptions из старого хранилища** - `969a994` (test)

**Plan metadata:** committed separately by orchestrator (worktree mode — STATE.md/ROADMAP.md updates excluded)

_Note: тест-файл написан и запущен на зелёный результат во время Task 1 (verify ссылается на него), формальный коммит теста выполнен отдельным Task 3 — атомарность коммитов по задачам сохранена._

## Files Created/Modified
- `lib/features/transcription/transcription_options.dart` - enum `TranscriptionProviderId`, enum `TranscriptionModel(provider, apiValue)`, словарь `_legacyModelAliases`, `TranscriptionOptions` теперь хранит `TranscriptionModel`, миграция в `fromJson`
- `lib/ui/screens/settings_screen.dart` - `_modelLabel`/`_pickOne` переведены на `TranscriptionModel`, добавлена ветка `nova3 => 'Nova-3'`
- `test/features/settings/transcription_options_migration_test.dart` - тест миграции: legacy→new, новый формат, мусор→fallback, round-trip, свойства enum

## Decisions Made
- WhisperModel удалён полностью (0 ссылок в `lib/`, проверено `grep -rc`); провайдер выводится из `model.provider`, отдельного поля провайдера в `TranscriptionOptions` нет — соответствует целевой архитектуре из дизайн-документа.
- Миграция реализована через явный словарь алиасов `_legacyModelAliases`, проверяемый первым в `fromJson` — самый явный и тестируемый способ обработки старого формата без скрытой логики внутри `firstWhere`.
- `settings_screen.dart` изменён минимально (только тип enum + один лейбл) — никакой UI-логики, вёрстки, glass-компонентов или дизайн-токенов не затронуто; фильтрация моделей по доступности ключей оставлена будущей UI-фазе (07-SPEC.md явно выводит это за рамки).

## Deviations from Plan

None - план выполнен как написан. Дополнительно подтверждено, что `WhisperModel` отсутствует во ВСЕХ файлах `lib/` (не только в двух файлах плана) — `groq_api_service.dart` и прочие потребители уже не ссылались на этот тип напрямую, упомянутая в плане «зачистка в 07-02» не требуется для этих файлов.

## Known Stubs

None.

## Threat Flags

None — изменения затрагивают только модель данных и сериализацию (имена enum, не секреты); провайдер `nova3` заведён исключительно как enum-значение, без сетевого/файлового кода.

## Self-Check: PASSED
