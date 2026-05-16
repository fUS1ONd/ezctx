---
status: partial
phase: 01-walking-skeleton-short-audio-clipboard
source:
  - 01-01-SUMMARY.md
  - 01-02-SUMMARY.md
started: "2026-05-17"
updated: "2026-05-17"
---

## Current Test

[testing paused — APK not installed on device]

## Tests

### 1. Навигация — HomeScreen отображается корректно
expected: После запуска APK открывается HomeScreen с заголовком «Слух», подзаголовком «Расшифруй любой звук» и кнопкой загрузки. Фон — glassmorphism-градиент.
result: pass

### 2. Навигация к Настройкам
expected: Нажатие иконки настроек (gear/settings) на HomeScreen переходит на SettingsScreen. В шапке написано «Настройки», виден список с пунктом «API-ключи».
result: blocked
blocked_by: physical-device
reason: "APK не установлен на устройство"

### 3. Счётчик ключей в SettingsScreen
expected: Если ключей нет — subtitle строки «API-ключи» показывает «Нет ключей». После добавления ключа и возврата — показывает «1 активен».
result: blocked
blocked_by: physical-device
reason: "APK не установлен на устройство"

### 4. Добавление API-ключа
expected: На ApiKeysScreen вводишь ключ длиной 20+ символов (например gsk_test12345678901234567890), нажимаешь «Добавить ключ» — появляется SnackBar «Ключ сохранён», ключ отображается в маскированном виде (последние 4 символа + точки), TextField очищается.
result: blocked
blocked_by: physical-device
reason: "APK не установлен на устройство"

### 5. Маскирование — ключ не виден полностью
expected: Добавленный ключ в списке ApiKeysScreen отображается как «••••••••••••••••XXXX» (16 точек + последние 4 символа). Полный ключ нигде не показан.
result: blocked
blocked_by: physical-device
reason: "APK не установлен на устройство"

### 6. Валидация — короткий ключ отклоняется
expected: При вводе строки короче 20 символов и нажатии «Добавить ключ» — ключ НЕ сохраняется, под полем появляется текст об ошибке (красный), SnackBar не показывается.
result: blocked
blocked_by: physical-device
reason: "APK не установлен на устройство"

### 7. Удаление ключа с подтверждением
expected: Нажатие на кнопку удаления (иконка корзины) рядом с ключом открывает AlertDialog «Удалить ключ?». При подтверждении — ключ удаляется из списка. При «Отмена» — ключ остаётся.
result: blocked
blocked_by: physical-device
reason: "APK не установлен на устройство"

### 8. Персистентность — ключ сохраняется после перезапуска
expected: Добавленный ключ виден в ApiKeysScreen после полного закрытия и повторного открытия приложения (flutter_secure_storage).
result: blocked
blocked_by: physical-device
reason: "APK не установлен на устройство"

## Summary

total: 8
passed: 1
issues: 0
skipped: 0
blocked: 7
pending: 0

## Gaps

[none yet]
