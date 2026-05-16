---
plan: 01-03
phase: 01-walking-skeleton-short-audio-clipboard
status: completed
completed_at: "2026-05-17"
requirements_closed:
  - IMPORT-01
  - IMPORT-02
---

# Summary: Plan 01-03 — File Import

## Что реализовано

### Task 1: SelectedAudioFile + FileValidator + unit тесты
- `lib/features/transcription/selected_audio_file.dart` — доменная модель файла (path, name, sizeBytes, extension, sizeFormatted)
- `lib/features/transcription/file_validator.dart` — чистая функция валидации: whitelist 9 расширений из `AppConstants.supportedAudioExtensions` + проверка размера ≤ 19 МБ
- `test/unit/file_validator_test.dart` — 19 проходящих тестов (заменена Wave 0 заглушка):
  - 9 whitelist расширений (mp3, wav, m4a, ogg, flac, mp4, mpeg, mpga, webm)
  - регистронезависимость (MP3 → mp3)
  - 2 path-кейса (полный путь, точка в папке)
  - 4 reject-кейса (.txt, .aac, .opus, без расширения)
  - 3 size-кейса (19 МБ ok, 20 МБ reject, 0 байт ok)

### Task 2: FilePickerService
- `lib/features/transcription/file_picker_service.dart` — обёртка над `file_picker` v11 (статический API `FilePicker.pickFiles`)
- Sealed-иерархия результата: `FilePickPicked` / `FilePickCancelled` (публичные классы)
- Валидация через `FileValidator` после выбора файла
- Бросает `ValidationException` при невалидном файле
- Примечание: FilePickerService тестируется на устройстве (FilePicker — статический singleton, unit-mock нецелесообразен)

### Task 3: HomeScreen — file picker integration
- `lib/ui/screens/home_screen.dart` — переработан из `StatelessWidget` в `StatefulWidget`
- State: `_selectedFile`, `_errorMessage`, `_picking`
- Tap на upload-card → открывает file picker через `FilePickerService.pickAudioFile()`
- Пустое состояние: иконка upload 72×72 + «Выберите файл» + «mp3, wav, m4a, ogg, flac · до 19 МБ»
- Файл выбран: preview с иконкой audiotrack 56×56 + имя файла + размер·формат + «Заменить»
- Ошибка валидации: `Text` с `AppColors.bad` под карточкой
- `_picking == true`: `CircularProgressIndicator` поверх upload-иконки
- `PrimaryButton('Транскрибировать')` активна только при `_selectedFile != null`

## Тесты

| Команда | Результат |
|---------|-----------|
| `flutter test test/unit/file_validator_test.dart` | ✓ 19/19 passed |
| `flutter test` | ✓ 33 passed, 3 skipped |
| `flutter analyze` | ✓ 0 issues |

## Требования

- **IMPORT-01** (file_picker SAF) — ✓ закрыт через `FilePickerService`
- **IMPORT-02** (whitelist + size validation) — ✓ закрыт через `FileValidator` + 19 тестов
