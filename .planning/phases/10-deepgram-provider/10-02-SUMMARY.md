---
phase: 10-deepgram-provider
plan: "02"
subsystem: storage
tags: [storage, di, deepgram, namespace, secure-storage]
dependency_graph:
  requires: []
  provides: [deepgramSecureStorageProvider, deepgramApiKeyRepoProvider, deepgramApiKeysProvider]
  affects: [lib/core/providers/storage_providers.dart, lib/core/providers/repository_providers.dart]
tech_stack:
  added: []
  patterns: [namespace-parameterized-storage, di-provider-mirror]
key_files:
  created: []
  modified:
    - lib/core/constants/app_constants.dart
    - lib/core/storage/secure_storage_service.dart
    - lib/features/settings/api_key_repository.dart
    - lib/core/providers/storage_providers.dart
    - lib/core/providers/repository_providers.dart
decisions:
  - "Вариант A: namespace через конструктор SecureStorageServiceImpl, ApiKeyRepository без изменений"
  - "Default storageKey = groq_api_keys_v1 — обратная совместимость (T-10-03)"
metrics:
  duration: "5m"
  completed: "2026-06-10T17:58:44Z"
  tasks_completed: 2
  tasks_total: 2
---

# Phase 10 Plan 02: Параметризованное хранилище ключей + Deepgram DI провайдеры

Параметризован `SecureStorageServiceImpl` по namespace через конструктор (default = Groq); заведены DI-двойники `deepgramSecureStorageProvider`, `deepgramApiKeyRepoProvider`, `deepgramApiKeysProvider` под изолированный namespace `deepgram_api_keys_v1`.

## Tasks

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Параметризовать SecureStorageServiceImpl | d91ffa3 | app_constants.dart, secure_storage_service.dart, api_key_repository.dart |
| 2 | DI-двойники Deepgram | ed790b5 | storage_providers.dart, repository_providers.dart |

## Decisions Made

1. **Вариант A — namespace через storage** (`ApiKeyRepository` без изменений логики): namespace пробрасывается в `SecureStorageServiceImpl`, репозиторий работает с любым провайдером прозрачно.
2. **Default storageKey = `groq_api_keys_v1`**: вызов `SecureStorageServiceImpl()` без аргументов сохраняет Groq-поведение — обратная совместимость (T-10-03).
3. **Добавить `storageKeyDeepgramApiKeys` в AppConstants**: единый источник правды для namespace-строк, без магических строк.

## Deviations from Plan

**1. [Rule 2 - Missing constant] Добавлена константа AppConstants.storageKeyDeepgramApiKeys**
- **Found during:** Task 2 (при написании `storage_providers.dart` обнаружено отсутствие константы)
- **Issue:** `storageKeyDeepgramApiKeys` не существовал в `AppConstants` до этого плана
- **Fix:** Добавлена `static const String storageKeyDeepgramApiKeys = 'deepgram_api_keys_v1'` в блок "Secure storage keys"
- **Files modified:** lib/core/constants/app_constants.dart (Task 1 commit)
- **Commit:** d91ffa3

## Verification

- `flutter analyze lib/core/storage/ lib/core/providers/ lib/features/settings/api_key_repository.dart` — No issues found.
- grep-проверки: все acceptance criteria Task 1 и Task 2 прошли.
- Groq-default (`storageKeyApiKeys`) неизменён — `SecureStorageServiceImpl()` без аргументов использует `groq_api_keys_v1`.

## Known Stubs

None.

## Threat Flags

None — новые network endpoints, auth paths или schema changes не введены. Namespace-изоляция реализована в соответствии с T-10-03.

## Self-Check: PASSED

- [x] d91ffa3 существует: `refactor(10-02): параметризовать SecureStorageServiceImpl по namespace`
- [x] ed790b5 существует: `feat(10-02): DI-двойники Deepgram (storage + repository providers)`
- [x] SUMMARY.md создан в `.planning/phases/10-deepgram-provider/`
- [x] `final String _storageKey` в secure_storage_service.dart (нет `static const _storageKey`)
- [x] `deepgramSecureStorageProvider` в storage_providers.dart
- [x] `deepgramApiKeyRepoProvider` и `deepgramApiKeysProvider` в repository_providers.dart
