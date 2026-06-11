---
phase: 07-provider-abstraction
plan: 02
subsystem: transcription
tags: [dart, flutter, interface, refactor, provider-abstraction, groq]

# Dependency graph
requires: ["enum TranscriptionModel(provider, apiValue)", "enum TranscriptionProviderId { groq, deepgram }"]
provides:
  - "abstract interface class TranscriptionProvider (transcribeChunk, concurrencyFor, id)"
  - "class GroqProvider implements TranscriptionProvider — рефактор GroqApiService 1:1"
  - "Provider<TranscriptionProvider> transcriptionProviderProvider в DI"
affects: [10-deepgram-provider, 11-ui-provider-selection]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Провайдеро-независимый интерфейс инкапсулирует всю специфику API (URL, тело запроса, MIME, парсинг, маппинг ошибок, политика конкурентности)"
    - "Политика конкурентности — метод интерфейса concurrencyFor(aliveKeyCount), вызываемый контроллером вместо встроенной формулы"
    - "Тестовые моки реализуют интерфейс через `implements`, а не наследуют конкретный класс — работает благодаря отсутствию сетевого single-shot метода в контракте"

key-files:
  created:
    - lib/features/transcription/transcription_provider.dart
  modified:
    - lib/features/transcription/groq_api_service.dart
    - lib/core/providers/service_providers.dart
    - lib/features/transcription/chunked_transcription_controller.dart
    - lib/ui/screens/processing_screen.dart
    - test/unit/groq_service_test.dart
    - test/unit/groq_transcribe_chunk_test.dart
    - test/unit/groq_api_service_rate_limit_test.dart
    - test/features/transcription/chunked_transcription_controller_test.dart
    - test/features/transcription/integration_chunked_flow_test.dart

key-decisions:
  - "Интерфейс не объявляет single-shot transcribe(SelectedAudioFile ...) — это узкий Groq-only путь; благодаря этому тестовые моки могут implements TranscriptionProvider без обязанности реализовывать сетевой код"
  - "concurrencyFor вынесен из формулы контроллера в GroqProvider (clamp(1, kMaxConcurrentChunks)) — поведение идентично, но политика теперь инкапсулирована в провайдере"
  - "Класс GroqApiService переименован в GroqProvider в существующем файле groq_api_service.dart (без создания нового groq_provider.dart) — согласно дизайн-документу"
  - "Мок-классы тестов переименованы из _MockGroqApiService в _MockTranscriptionProvider и переключены с extends на implements — соответствует новой архитектуре и снимает зависимость от конкретной реализации"

patterns-established:
  - "concurrencyFor(aliveKeyCount) — единственное место, знающее политику конкурентности конкретного провайдера; контроллер и пул её не знают"

requirements-completed: []

# Metrics
duration: ~35min
completed: 2026-06-08
---

# Phase 07 Plan 02: Провайдеро-независимый интерфейс TranscriptionProvider Summary

**Введён интерфейс `TranscriptionProvider` (transcribeChunk/concurrencyFor/id), а `GroqApiService` рефакторен в `GroqProvider implements TranscriptionProvider` байт-в-байт без изменения HTTP-контракта — контроллер, DI и UI-экран теперь зависят от абстракции, а не от конкретной реализации.**

## Performance

- **Duration:** ~35 min
- **Tasks:** 3/3
- **Files modified:** 9 (1 создан, 8 изменено)

## Accomplishments
- Создан `abstract interface class TranscriptionProvider` с методами `transcribeChunk`, `concurrencyFor(aliveKeyCount)`, `id` — спроектирован так, что будущий `DeepgramProvider` (Phase 10) встанет без изменения сигнатур; `transcribe(SelectedAudioFile ...)` намеренно НЕ входит в контракт.
- `GroqApiService` переименован в `GroqProvider implements TranscriptionProvider` в том же файле `groq_api_service.dart`; тела `transcribeChunk`/`transcribe`, обработка ошибок, парсинг `retry-after`, конструктор с `clientFactory` оставлены без изменения логики (байт-в-байт тот же HTTP-запрос).
- `concurrencyFor` инкапсулирует политику «поток на ключ» (`aliveKeyCount.clamp(1, kMaxConcurrentChunks)`), вынесенную из контроллера — поведение идентично прежнему.
- DI-провайдер `groqApiServiceProvider` переименован в `transcriptionProviderProvider` типа `Provider<TranscriptionProvider>`; обновлены все потребители (`chunked_transcription_controller.dart`, `processing_screen.dart`).
- Тестовые моки переключены с `extends GroqApiService` на `implements TranscriptionProvider` (переименованы в `_MockTranscriptionProvider`), добавлены `concurrencyFor`/`id`, `concurrencyFor` ссылается на `AppConstants.kMaxConcurrentChunks` (без магических чисел).
- `flutter analyze` по всему проекту — чисто (0 errors/warnings, новых не добавлено); полный `flutter test` зелёный.

## Task Commits

Each task was committed atomically:

1. **Task 1: Спроектировать интерфейс TranscriptionProvider** — `c15c33c` (feat)
2. **Task 2: Рефактор GroqApiService → GroqProvider implements TranscriptionProvider** — `41d86b9` (refactor)
3. **Task 3: Обновить тесты-моки под TranscriptionProvider** — `0dacbe4` (test)

**Plan metadata:** committed separately by orchestrator (worktree mode — STATE.md/ROADMAP.md updates excluded)

## Files Created/Modified
- `lib/features/transcription/transcription_provider.dart` — НОВЫЙ: интерфейс `TranscriptionProvider` (только сигнатуры, doc-комментарии на русском, контракт ошибок и политика конкурентности задокументированы)
- `lib/features/transcription/groq_api_service.dart` — `GroqApiService` → `class GroqProvider implements TranscriptionProvider`; добавлены `@override concurrencyFor`, `@override id`; `transcribe(...)` остался публичным методом класса (вне интерфейса)
- `lib/core/providers/service_providers.dart` — `groqApiServiceProvider` → `transcriptionProviderProvider` типа `Provider<TranscriptionProvider>` → `GroqProvider()`
- `lib/features/transcription/chunked_transcription_controller.dart` — поле `_api`/параметр конструктора типизированы как `TranscriptionProvider` (имя `apiService:` сохранено); конкурентность через `_api.concurrencyFor(_pool.aliveKeyCount)`; удалён ставший неиспользуемым импорт `app_constants.dart`
- `lib/ui/screens/processing_screen.dart` — `ref.read(groqApiServiceProvider)` → `ref.read(transcriptionProviderProvider)`
- `test/unit/groq_service_test.dart`, `test/unit/groq_transcribe_chunk_test.dart`, `test/unit/groq_api_service_rate_limit_test.dart` — `GroqApiService` → `GroqProvider` в конструкциях и описаниях групп (asserts не изменены)
- `test/features/transcription/chunked_transcription_controller_test.dart`, `test/features/transcription/integration_chunked_flow_test.dart` — мок `_MockGroqApiService extends GroqApiService` → `_MockTranscriptionProvider implements TranscriptionProvider`, добавлены `concurrencyFor`/`id`, импортирован `app_constants.dart`/`transcription_provider.dart`

## Decisions Made
- Интерфейс умышленно не включает `transcribe(SelectedAudioFile ...)` — это сохраняет возможность мокам использовать `implements TranscriptionProvider` без обязанности реализовывать сетевой single-shot путь (зафиксировано в acceptance Task 1, использовано в Task 3).
- `concurrencyFor` объявлен методом интерфейса и реализован в `GroqProvider`, чтобы политика конкурентности каждого провайдера инкапсулировалась в самом провайдере — контроллер и пул её не знают.
- Мок-классы переименованы из `_MockGroqApiService` в `_MockTranscriptionProvider`, чтобы полностью устранить упоминания старого имени класса (это требовалось грепом из `<verification>` плана: `grep -rv '^#' lib test | grep -c "GroqApiService"` == 0).
- Удалён ставший неиспользуемым импорт `app_constants.dart` из контроллера (рефакторинг убрал единственное использование `AppConstants.kMaxConcurrentChunks` оттуда — Rule 1, иначе `flutter analyze` выдал бы предупреждение о неиспользуемом импорте).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Удалён неиспользуемый импорт app_constants.dart из контроллера**
- **Найдено во время:** Task 2
- **Проблема:** После замены формулы конкурентности на `_api.concurrencyFor(...)` импорт `app_constants.dart` в `chunked_transcription_controller.dart` остался единственной причиной — `AppConstants` больше нигде в файле не используется, что вызвало бы предупреждение анализатора о неиспользуемом импорте.
- **Исправление:** Импорт удалён, список импортов приведён к алфавитному порядку (соответствует существующему стилю файла).
- **Файлы:** `lib/features/transcription/chunked_transcription_controller.dart`
- **Коммит:** `41d86b9`

**2. [Rule 1 - Bug] Переименованы мок-классы _MockGroqApiService → _MockTranscriptionProvider**
- **Найдено во время:** Task 3
- **Проблема:** План указывал переключить `_MockGroqApiService extends GroqApiService` на `implements TranscriptionProvider`, но не уточнял переименование самого класса. При этом верификационный grep плана (`grep -rv '^#' lib test | grep -c "GroqApiService"` == 0) включал бы и имя `_MockGroqApiService` — оставление старого имени привело бы к ложному «провалу» этой проверки и к рассинхронизации имени мока с новой архитектурой.
- **Исправление:** Класс и все его конструкции переименованы в `_MockTranscriptionProvider` в обоих тест-файлах (контроллера и интеграционном); doc-комментарии обновлены.
- **Файлы:** `test/features/transcription/chunked_transcription_controller_test.dart`, `test/features/transcription/integration_chunked_flow_test.dart`
- **Коммит:** `0dacbe4`

## Known Stubs

None.

## Threat Flags

None — рефактор не добавляет новой сетевой/файловой/auth поверхности; HTTP-контракт Groq, обработка ошибок и retry-after парсинг (включая cap 3600 с из T-04-02) не изменены. apiKey по-прежнему передаётся аргументом из пула и не персистится.

## Self-Check: PASSED
