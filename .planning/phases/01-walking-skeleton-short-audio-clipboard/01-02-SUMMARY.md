---
plan: 01-02
status: completed
completed_at: "2026-05-17"
requirements_closed:
  - KEYS-01
  - KEYS-02
---

# Summary: Plan 01-02 — API Keys CRUD

## Что сделано

- **ApiKeyRepository** (`lib/features/settings/api_key_repository.dart`) — фасад над `SecureStorageService` с валидацией, trim, маскированием и идемпотентностью. Единственный путь к ключам из feature-слоя.
- **ApiKeysScreen** (`lib/ui/screens/api_keys_screen.dart`) — полностью переписан: список маскированных ключей, TextField для ввода, кнопка «Добавить ключ», удаление с диалогом подтверждения, footer с ссылкой на console.groq.com.
- **SettingsScreen** (`lib/ui/screens/settings_screen.dart`) — конвертирован в `StatefulWidget`, показывает актуальный счётчик ключей (`$_keyCount активен` / `Нет ключей`), обновляется при возврате из ApiKeysScreen.
- **Skeleton API изолирован**: методы `writeRawKey/readRawKey/deleteRawKey` в `SecureStorageServiceImpl` помечены `@Deprecated`.

## Тест-кейсы api_key_repository_test.dart (9 из 9)

| # | Группа | Тест | Статус |
|---|--------|------|--------|
| 1 | addKey | добавляет валидный ключ | ✅ |
| 2 | addKey | пустая строка → ValidationException | ✅ |
| 3 | addKey | строка только из пробелов → ValidationException | ✅ |
| 4 | addKey | короткий ключ → ValidationException | ✅ |
| 5 | addKey | trim пробелов перед сохранением | ✅ |
| 6 | addKey | идемпотентность — дубликат не добавляется | ✅ |
| 7 | removeKey | удаляет указанный ключ | ✅ |
| 8 | mask | последние 4 символа видны, середина точками | ✅ |
| 9 | mask | слишком короткий ключ полностью скрыт | ✅ |

## Grep-аудит Single Source of Truth

```
grep -rn "FlutterSecureStorage" lib/ | grep -v "secure_storage_service.dart"
# → (пусто)

grep -rn "writeRawKey|readRawKey|deleteRawKey" lib/ | grep -v "secure_storage_service.dart"
# → (пусто)
```

Нарушений не найдено. Skeleton API не вызывается нигде в feature-коде.

## Верификация

- `flutter analyze --no-fatal-infos` → **No issues found**
- `flutter test` → **14 passed, 4 skipped** (все unit-тесты зелёные)
- Коммит: `edf4dba`
