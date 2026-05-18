# Phase 5: Model & Language Controls — Context

## Phase Boundary

**In scope:**
- `TranscriptionOptions` value object (`WhisperModel` + `TranscriptionLanguage`)
- `TranscriptionOptionsRepository` — сохранение настроек в `flutter_secure_storage`
- Обновление `GroqApiService.transcribe()` и `transcribeChunk()` — принимают `TranscriptionOptions`; поле `language` добавляется только при явном выборе (не Авто)
- `ProcessingArgs` — добавление поля `options: TranscriptionOptions`
- `TranscriptionController.start()` и `ChunkedTranscriptionController.start()` — принимают и пробрасывают `TranscriptionOptions`
- UI на `HomeScreen`: переключатель модели (`large-v3` / `large-v3-turbo`) + селектор языка
- `ProcessingScreen` — читает `options` из `ProcessingArgs`, передаёт в контроллеры

**Out of scope (Phase 6+):**
- SRT/субтитровый вывод
- История транскрибаций
- Онбординг / welcome screen

## Implementation Decisions

### D-01 — TranscriptionOptions как immutable value object
`TranscriptionOptions` — `@immutable` класс с `WhisperModel model` и `TranscriptionLanguage language`. Нет `ChangeNotifier`, нет `freezed` — не нужен. Создаётся на HomeScreen и передаётся через `ProcessingArgs`.

### D-02 — Хранение настроек через flutter_secure_storage
Нет `shared_preferences` в зависимостях. Для настроек используем тот же `FlutterSecureStorage` через новый `TranscriptionOptionsRepository`. Ключ: `AppConstants.storageKeyTranscriptionOptions`. JSON-сериализация: `{'model': 'large-v3', 'language': 'ru'}`.

**Альтернатива:** добавить `shared_preferences` — отклонена, нет смысла тащить пакет для двух полей.

### D-03 — Язык «Авто» = нет поля language в запросе
При `TranscriptionLanguage.auto` поле `language` не добавляется в multipart-запрос к Groq. При явном выборе — добавляется ISO-639-1 код (ru, en, de, fr, es, uk, zh, ja, ko, ar).

### D-04 — UI: SegmentedButton для модели, GlassTile/DropdownButton для языка
`SegmentedButton<WhisperModel>` (Material 3) для toggle модели. Список языков — `DropdownButton` внутри `GlassCard`; 10 вариантов + Авто. Оба контрола размещаются в `HomeScreen` перед кнопкой «Транскрибировать», загружаются через `TranscriptionOptionsRepository.load()` в `initState`.

### D-05 — Нет нового экрана настроек модели
Контролы модели и языка живут прямо на `HomeScreen` — пользователь видит их до каждой транскрибации, не нужно переходить в настройки.

## Canonical References

### Требования
- OPTS-01: Переключатель модели large-v3 / large-v3-turbo; дефолт large-v3; сохраняется между сессиями
- OPTS-02: Селектор языка Авто / ru / en / +основные; дефолт Авто
- OPTS-03: При Авто — поле language отсутствует в запросе; при явном выборе — ISO-код

### Существующий код (обязательно прочитать перед планированием)
- `lib/features/transcription/groq_api_service.dart` — `transcribe()` строки ~100–140, `transcribeChunk()` строки ~45–95
- `lib/features/transcription/processing_args.dart` — 12 строк, только `file` и `metadata`
- `lib/features/transcription/transcription_controller.dart` — `start(SelectedAudioFile file)` строки ~67–88
- `lib/features/transcription/chunked_transcription_controller.dart` — `start(NormalizedAudioFile file)` внутри класса
- `lib/ui/screens/processing_screen.dart` — `initState()` создаёт контроллеры, строки ~60–80
- `lib/ui/screens/home_screen.dart` — `_onTranscribeTap()` передаёт `ProcessingArgs`
- `lib/core/constants/app_constants.dart` — `groqDefaultModel = 'whisper-large-v3'`, `storageKeyApiKeys`
- `lib/core/storage/secure_storage_service.dart` — паттерн JSON-хранения

## Existing Code Insights

### Reusable Assets
- `GlassCard`, `GlassTile` — готовые glass-контейнеры для UI контролов
- `AppTextStyles.body`, `AppTextStyles.label` — типографика
- `AppColors.accent` — цвет активного сегмента
- `SecureStorageServiceImpl` — паттерн для `TranscriptionOptionsRepository`

### Established Patterns
- `@immutable` value object с named constructor (см. `SelectedAudioFile`, `AudioMetadata`)
- Dependency injection через конструктор
- `flutter_secure_storage` + JSON-сериализация (см. `SecureStorageServiceImpl.listApiKeys`)
- `initState` + async load (см. `SettingsScreen._load()`, `HomeScreen`)

### Integration Points
- `ProcessingArgs` → передаётся через `Navigator.pushNamed` как `arguments`
- `ProcessingScreen` читает args через `ModalRoute.of(context)!.settings.arguments`
- `TranscriptionController` и `ChunkedTranscriptionController` создаются в `ProcessingScreen.initState`

### Уже реализовано (не дублировать)
- Multi-key pool + rate-limit retry (Phase 4)
- Audio normalization pipeline (Phase 3)
- File chunking (Phase 2)

## Specific Ideas

### Разбивка по волнам
- **Wave 1 (05-01):** Core — `TranscriptionOptions` model + repository + `AppConstants` + `GroqApiService` update + `ProcessingArgs` update + controller update
- **Wave 2 (05-02):** UI — `HomeScreen` controls + `ProcessingScreen` wiring

### UI-макет HomeScreen (после file preview, перед кнопкой)
```
┌─────────────────────────────────────┐
│  GlassCard                          │
│  Модель              [large-v3 | ▸turbo] │
│  Язык                [Авто ▾]       │
└─────────────────────────────────────┘
[Транскрибировать]
```

## Deferred Ideas

- Кастомный ввод языка (ISO-код вручную) — в Phase 8 (polish)
- Отображение выбранной модели/языка на ProcessingScreen — Phase 8
- Настройки модели/языка через отдельный экран — не нужно для MVP
