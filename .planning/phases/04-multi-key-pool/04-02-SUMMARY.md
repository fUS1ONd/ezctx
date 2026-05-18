---
phase: 04-multi-key-pool
plan: "02"
subsystem: transcription
tags: [groq-key-pool, transcription-controller, chunked-controller, rate-limit-retry, wire-up]
dependency_graph:
  requires:
    - 04-01  # GroqKeyPool, AllKeysBlockedException, RateLimitException, kMaxConcurrentChunks
  provides:
    - ChunkedTranscriptionController с acquireKey/reportRateLimited
    - TranscriptionController с retry-loop через GroqKeyPool
    - main.dart singleton GroqKeyPool с initialKeys из SecureStorage
  affects:
    - lib/ui/screens/processing_screen.dart
    - lib/ui/app.dart
    - lib/ui/widgets/chunk_tile.dart
tech_stack:
  added: []
  patterns:
    - while-loop retry до 10 попыток (замена рекурсии через _withRetry)
    - singleton GroqKeyPool передаётся через конструктор (dependency injection без Provider)
    - acquireKey() ждёт живого ключа автоматически (пул блокирует до разблокировки)
key_files:
  created: []
  modified:
    - lib/features/transcription/chunked_transcription_controller.dart
    - lib/features/transcription/chunk_state.dart
    - lib/features/transcription/transcription_controller.dart
    - lib/main.dart
    - lib/ui/app.dart
    - lib/ui/screens/processing_screen.dart
    - lib/ui/widgets/chunk_tile.dart
decisions:
  - "GroqKeyPool singleton создан в main.dart до runApp(), передаётся через EzCtxApp → ProcessingScreen конструктор (без Provider/InheritedWidget)"
  - "EzCtxApp.onGenerateRoute переписан с Map<String, WidgetBuilder> на switch — для передачи groqKeyPool в ProcessingScreen"
  - "ChunkWaitingForKey добавлен в chunk_state.dart и обработан в ChunkTile (keys.off иконка)"
  - "TranscriptionController retry-loop: при RateLimitException продолжает цикл без задержки — acquireKey() сам ждёт живого ключа"
metrics:
  duration: "~25 минут"
  completed: "2026-05-18"
  tasks_completed: 2
  tasks_total: 2
  files_changed: 7
---

# Phase 04 Plan 02: Wave 2 — Миграция контроллеров на GroqKeyPool Summary

**One-liner:** Оба контроллера транскрибации мигрированы на pool.acquireKey()/reportRateLimited() с retry-loop до 10 попыток; GroqKeyPool singleton создан в main.dart с ключами из SecureStorage.

## Что сделано

### Задача 1: ChunkedTranscriptionController → GroqKeyPool (57ab3fa)

**Файлы:** `chunked_transcription_controller.dart`, `chunk_state.dart`

- Заменён параметр `keyRepository: ApiKeyRepository` на `pool: GroqKeyPool`
- Убраны `maxConcurrent` и `_semaphore` из конструктора — семафор создаётся в `start()` динамически
- Семафор: `min(pool.aliveKeyCount.clamp(1, kMaxConcurrentChunks), kMaxConcurrentChunks)`
- `_processChunk` переработан: убран параметр `apiKey`, добавлен while-loop до 10 попыток
- При `RateLimitException`: `pool.reportRateLimited(key, retryAfterSeconds)` + continue loop
- При `AuthException`: rethrow немедленно (без ретрая)
- При `NetworkException`: экспоненциальная задержка 5×2^attempt секунд, до 10 попыток
- Убран `_withRetry` метод (заменён on while-loop)
- Добавлен `ChunkWaitingForKey` в `chunk_state.dart` — показывается когда `aliveKeyCount == 0`

### Задача 2: TranscriptionController + Wire-up в main.dart (456f4a2)

**Файлы:** `transcription_controller.dart`, `main.dart`, `app.dart`, `processing_screen.dart`, `chunk_tile.dart`

- `TranscriptionController`: `ApiKeyRepository` → `GroqKeyPool`
- Retry-loop до 10 попыток при `RateLimitException` → `reportRateLimited` + продолжение
- `AllKeysBlockedException` → `TranscriptionError('Все ключи заблокированы...', retryable: true)`
- `main.dart`: создаёт `GroqKeyPool` singleton перед `runApp()` с `initialKeys` из SecureStorage
- `EzCtxApp`: принимает `groqKeyPool`, `onGenerateRoute` переписан на switch для передачи pool в `ProcessingScreen`
- `ProcessingScreen`: `groqKeyPool` как обязательный параметр, контроллеры создаются с pool
- `ChunkTile`: добавлен case `ChunkWaitingForKey()` с иконкой `Icons.key_off`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Critical Fix] ChunkTile не обрабатывал ChunkWaitingForKey**
- **Found during:** Task 2 — flutter analyze после добавления ChunkWaitingForKey в Task 1
- **Issue:** `switch (state)` в `chunk_tile.dart` — non_exhaustive_switch_expression, сборка не компилировалась
- **Fix:** Добавлен case `ChunkWaitingForKey()` с иконкой `Icons.key_off` и текстом "Ожидание ключа..."
- **Files modified:** `lib/ui/widgets/chunk_tile.dart`
- **Commit:** 456f4a2

**2. [Rule 3 - Architectural Adaptation] EzCtxApp.routeBuilders переписан на switch**
- **Found during:** Task 2 — `Map<String, WidgetBuilder>` не позволяет замыкание над `groqKeyPool`
- **Issue:** `_routeBuilders` — статическое поле, не имеет доступа к instance-полю `groqKeyPool`
- **Fix:** `onGenerateRoute` переписан со switch-expression вместо Map lookup
- **Files modified:** `lib/ui/app.dart`
- **Commit:** 456f4a2

## Self-Check

Проверка созданных файлов:
- ✓ `chunked_transcription_controller.dart` — содержит `acquireKey` (2 вхождения), нет `ApiKeyRepository`
- ✓ `transcription_controller.dart` — содержит `acquireKey` (2 вхождения), нет `ApiKeyRepository`
- ✓ `main.dart` — содержит `GroqKeyPool` (3 вхождения)
- ✓ `chunk_state.dart` — содержит `ChunkWaitingForKey`

Проверка коммитов:
- ✓ 57ab3fa — feat(04-02): мигрировать ChunkedTranscriptionController
- ✓ 456f4a2 — feat(04-02): мигрировать TranscriptionController + wire-up

flutter analyze lib/ → 0 ошибок (7 info pre-existing в несмежных файлах)

## Self-Check: PASSED
