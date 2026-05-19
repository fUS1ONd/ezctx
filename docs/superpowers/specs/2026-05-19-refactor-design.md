# Дизайн: Рефакторинг архитектуры и UI (Phase Refactor)

**Дата:** 2026-05-19  
**Ветка:** `refactor/repo-cleanup`  
**Статус:** Согласован

---

## Цель

Подготовить кодовую базу к грядущим фичам (история транскрипций, фоновая обработка, равномерное распределение чанков) без изменения существующей функциональности. Улучшить UI в двух точках: экран настроек и баннер «нет ключей».

---

## Что В Рамках (In Scope)

- Введение Riverpod как DI-контейнера
- Bottom navigation bar (Главная / История-placeholder / Настройки)
- Переработанный `SettingsScreen`: модель, язык, тема, иконка-placeholder, уведомления-placeholder
- Баннер «нет ключей» на `HomeScreen` в стиле проекта
- Читаемые сообщения об ошибках (429, 401, сеть)
- Разбивка `ProcessingScreen` на виджеты
- Удаление карточки модель/язык с `HomeScreen`

## Что НЕ В Рамках (Out of Scope)

- Реализация экрана истории (только placeholder)
- Фоновая обработка / Foreground Service (отдельная фаза)
- Равномерное распределение чанков (ветка `plan/phase-09`)
- `go_router` (навигация остаётся на `MaterialApp.onGenerateRoute`)
- Переписывание `ChunkedTranscriptionController` на Riverpod

---

## Подход: Послойный рефакторинг (4 шага)

Каждый шаг — атомарный коммит. Работоспособность проверяется после каждого.

---

## Слой 1: DI через Riverpod

### Новые файлы

```
lib/core/providers/
  storage_providers.dart        // SecureStorageService
  repository_providers.dart     // ApiKeyRepository, TranscriptionOptionsRepository
  service_providers.dart        // GroqApiService, GroqKeyPool, AudioChunkingService
```

### Изменения

- `main.dart` — обернуть `MyApp` в `ProviderScope`
- `HomeScreen` — убрать создание `ApiKeyRepository` в State, использовать `ref.watch(apiKeyRepoProvider)`
- `ProcessingScreen` — получать `GroqKeyPool` через `ref.watch(groqKeyPoolProvider)`, не через параметр конструктора
- `SettingsScreen` и `ApiKeysScreen` — аналогично

### Правила провайдеров

```dart
// storage_providers.dart
@riverpod
SecureStorageService secureStorage(Ref ref) => SecureStorageServiceImpl();

// repository_providers.dart
@riverpod
ApiKeyRepository apiKeyRepo(Ref ref) =>
    ApiKeyRepository(ref.watch(secureStorageProvider));

@riverpod
TranscriptionOptionsRepository transcriptionOptionsRepo(Ref ref) =>
    TranscriptionOptionsRepository(ref.watch(secureStorageProvider));

// service_providers.dart
@riverpod
GroqKeyPool groqKeyPool(Ref ref) =>
    GroqKeyPool(ref.watch(apiKeyRepoProvider));

@riverpod
GroqApiService groqApiService(Ref ref) => GroqApiService();

@riverpod
AudioChunkingService audioChunkingService(Ref ref) => AudioChunkingService();
```

`ChunkedTranscriptionController` — остаётся `ChangeNotifier`, без изменений. Тесты на него не трогаем.

---

## Слой 2: Навигация + Bottom Nav

### `AppRouter`

Простой класс (`lib/core/router/app_router.dart`) с `static Map<String, WidgetBuilder> routes`. Без `go_router`.

### Bottom Nav Shell

Новый виджет `ScaffoldWithNavBar` — `IndexedStack` с тремя вкладками:

| Индекс | Вкладка | Экран |
|--------|---------|-------|
| 0 | Главная | `HomeScreen` |
| 1 | История | `HistoryPlaceholderScreen` |
| 2 | Настройки | `SettingsScreen` |

`ProcessingScreen` и `ResultScreen` пушатся поверх через `Navigator.push` — они не вкладки, а флоу.

### `HistoryPlaceholderScreen`

Минимальный экран: иконка + текст «История появится скоро». Готов к замене на реальную реализацию.

### Стиль bottom nav

Кастомный `BottomNavigationBar` в стиле проекта: `GradientBackground`, иконки `home_outlined / history_outlined / settings_outlined`, активная иконка меняет цвет на `AppColors.accent`.

---

## Слой 3: Переработанный SettingsScreen

### Структура экрана

```
Подключение
  API-ключи Groq      [количество ключей]  →
  Модель              [Whisper Large v3]    →   ← перенесено с HomeScreen
  Язык                [Авто]               →   ← перенесено с HomeScreen

Внешний вид
  Тема                [Авто / Светлая / Тёмная]  toggle
  Иконка приложения   [Дневная / Ночная]          toggle (placeholder UI)

Уведомления
  Уведомления о завершении  [toggle]  (placeholder, всегда true)
```

### Тема

- `ThemeMode` хранится в `SecureStorageService` под ключом `app_theme_mode`
- Новый провайдер `themeModeProvider` (StateNotifier)
- `MaterialApp` в `app.dart` наблюдает `themeModeProvider`

### Иконка приложения

UI-переключатель есть, реальная смена иконки — отдельная задача (требует `activity-alias` в AndroidManifest). В этой фазе — только хранение выбора.

### Уведомления

Placeholder toggle. Значение хранится, но никакого кода уведомлений не создаётся (фоновая обработка — отдельная фаза).

### Убрать с HomeScreen

Карточка «Модель и язык» (`_buildModelAndLanguageCard`) удаляется. Настройки читаются глобально из `transcriptionOptionsRepoProvider`.

### Баннер «нет ключей» на HomeScreen

```
┌─ GlassTile ───────────────────────────────────────┐
│  🔑  Добавьте API-ключ Groq для транскрибации      │
│                               [Открыть настройки] │
└───────────────────────────────────────────────────┘
```

- Появляется если `apiKeyRepo.getAll().isEmpty` (через `ref.watch`)
- Исчезает сразу после добавления первого ключа
- Кнопка «Открыть настройки» → переключает bottom nav на вкладку Settings

---

## Слой 4: Очистка ProcessingScreen

### Экстракция виджетов

| Виджет | Файл |
|--------|------|
| `PipelineStepTile` | `lib/ui/widgets/pipeline_step_tile.dart` |
| `ChunkedProgressSection` | `lib/ui/widgets/chunked_progress_section.dart` |

`ProcessingScreen` сокращается до координирующего StatefulWidget — только жизненный цикл и сборка, без inline-логики построения виджетов.

### Читаемые ошибки

`AppException` — sealed class с подклассами (`RateLimitException`, `AuthException`, `NetworkException`, `ValidationException`, `InternalException`, `AllKeysBlockedException`). Новый extension в `lib/core/error/app_exception.dart`:

```dart
extension AppExceptionUserMessage on AppException {
  String get userMessage => switch (this) {
    RateLimitException(:final retryAfterSeconds) =>
        'Превышен лимит Groq. Попробуйте через $retryAfterSeconds с.',
    AllKeysBlockedException() =>
        'Все API-ключи заблокированы лимитом. Подождите или добавьте ещё ключи.',
    AuthException() =>
        'Неверный API-ключ. Проверьте настройки.',
    NetworkException() =>
        'Нет подключения к интернету.',
    ValidationException(:final message) => message,
    InternalException() =>
        'Внутренняя ошибка. Попробуйте ещё раз.',
  };
}
```

Этот extension используется везде где показывается ошибка пользователю — в `ProcessingScreen`, `HomeScreen`, `ApiKeysScreen`.

---

## Структура файлов (финальная)

```
lib/
├── core/
│   ├── constants/        (без изменений)
│   ├── error/            (+ extension AppErrorMessage)
│   ├── providers/        ← НОВОЕ
│   │   ├── storage_providers.dart
│   │   ├── repository_providers.dart
│   │   └── service_providers.dart
│   ├── router/           ← НОВОЕ
│   │   └── app_router.dart
│   └── services/         (без изменений)
├── features/
│   ├── settings/         (без изменений)
│   └── transcription/    (без изменений)
└── ui/
    ├── app.dart          (обновить: ProviderScope, ThemeMode)
    ├── screens/
    │   ├── home_screen.dart         (убрать карточку модели/языка, добавить баннер)
    │   ├── history_screen.dart      ← НОВОЕ (placeholder)
    │   ├── processing_screen.dart   (сокращён — логика в виджетах)
    │   ├── result_screen.dart       (без изменений)
    │   ├── settings_screen.dart     (переработан)
    │   └── api_keys_screen.dart     (без изменений)
    └── widgets/
        ├── ...existing...
        ├── scaffold_with_nav_bar.dart   ← НОВОЕ
        ├── pipeline_step_tile.dart      ← НОВОЕ
        └── chunked_progress_section.dart ← НОВОЕ
```

---

## Зависимости (новые пакеты)

| Пакет | Версия | Назначение |
|-------|--------|------------|
| `flutter_riverpod` | `^2.6.0` | State management + DI |
| `riverpod_annotation` | `^2.6.0` | Кодогенерация провайдеров |
| `build_runner` | `^2.4.0` | dev_dependency |
| `riverpod_generator` | `^2.6.0` | dev_dependency |

---

## Тесты

- Существующие тесты `ChunkedTranscriptionController` — не трогаем
- Новые widget-тесты: `SettingsScreen` (тема toggle, навигация к API-ключам)
- Новый unit-тест: `AppErrorMessage` extension (429, 401, network)

---

## Детальный план по слоям (для автономного выполнения)

### Слой 1 — DI (порядок выполнения)

1. Добавить в `pubspec.yaml`: `flutter_riverpod: ^2.6.1`, `riverpod_annotation: ^2.6.1`; dev: `build_runner: ^2.4.13`, `riverpod_generator: ^2.6.1`
2. Создать `lib/core/providers/storage_providers.dart`
3. Создать `lib/core/providers/repository_providers.dart`
4. Создать `lib/core/providers/service_providers.dart`
5. Обернуть `runApp` в `ProviderScope` в `main.dart`
6. Обновить `HomeScreen` → `ConsumerStatefulWidget`, убрать `final ApiKeyRepository _repository = ...`
7. Обновить `ProcessingScreen` → убрать параметр `groqKeyPool`, получать через `ref.read(groqKeyPoolProvider)`
8. Обновить `SettingsScreen` → `ConsumerStatefulWidget`
9. Обновить `ApiKeysScreen` → `ConsumerStatefulWidget`
10. Запустить `flutter analyze` — исправить все ошибки

### Слой 2 — Навигация (порядок выполнения)

1. Создать `lib/ui/screens/history_screen.dart` — placeholder с `GradientBackground` + центрированный текст «История появится скоро» + иконка
2. Создать `lib/ui/widgets/scaffold_with_nav_bar.dart` — `StatefulWidget` с `IndexedStack([HomeScreen(), HistoryScreen(), SettingsScreen()])` и кастомным `BottomNavigationBar`
3. Стиль `BottomNavigationBar`: `backgroundColor: Colors.transparent`, `elevation: 0`, тип `fixed`, иконки `home_outlined / history_outlined / settings_outlined`, активная иконка `AppColors.accent`
4. Обновить `lib/ui/app.dart`: убрать прямой `home: HomeScreen()`, поставить `home: ScaffoldWithNavBar()`. `GradientBackground` переехал внутрь каждого экрана — не дублировать.
5. Убедиться что `ProcessingScreen` и `ResultScreen` пушатся через `Navigator.push` поверх `ScaffoldWithNavBar`
6. Запустить `flutter analyze`

### Слой 3 — Settings (порядок выполнения)

1. Добавить extension `AppExceptionUserMessage` в конец `lib/core/error/app_exception.dart`
2. Создать `lib/core/providers/theme_provider.dart` — `StateNotifierProvider<ThemeModeNotifier, ThemeMode>` с сохранением в `SecureStorageService` под ключом `'app_theme_mode'`
3. Обновить `lib/ui/app.dart`: `themeMode: ref.watch(themeModeProvider)`, импорт `theme_provider.dart`. `app.dart` становится `ConsumerWidget`.
4. Добавить в `AppConstants`: `static const String storageKeyThemeMode = 'app_theme_mode';`
5. Добавить в `TranscriptionOptionsRepository` доступ к сохранённым настройкам (уже есть, убедиться что `SettingsScreen` читает через провайдер)
6. Переписать `SettingsScreen`:
   - Блок «Подключение»: `ListTile` для API-ключей (существующий), `ListTile` для Модели, `ListTile` для Языка
   - Блок «Внешний вид»: `SegmentedButton<ThemeMode>` (Авто / Светлая / Тёмная), `SwitchListTile` для иконки (placeholder, только хранит значение)
   - Блок «Уведомления»: `SwitchListTile` (placeholder, `true` по умолчанию)
   - Все блоки в `GlassCard`
7. Обновить `HomeScreen`:
   - Убрать метод `_buildModelAndLanguageCard` и его вызовы
   - Убрать `_options`/`_onOptionsChanged`/`_optionsRepo` поля
   - Читать `_options` через `ref.watch(transcriptionOptionsRepoProvider)` там где нужно при запуске транскрибации (в `_onTranscribeTap`)
   - Добавить баннер `_buildNoKeysBanner()` в начало Column: `GlassTile` с иконкой `Icons.key_off_outlined`, текстом «Добавьте API-ключ Groq» и `TextButton` «Открыть настройки» → `setState(() => ScaffoldWithNavBar.of(context)?.switchTab(2))` (или через колбэк)
8. Запустить `flutter test` и `flutter analyze`

### Слой 4 — Очистка ProcessingScreen (порядок выполнения)

1. Создать `lib/ui/widgets/pipeline_step_tile.dart` — вынести `_buildPipelineStep(...)` из `ProcessingScreen`
2. Создать `lib/ui/widgets/chunked_progress_section.dart` — вынести секцию `ChunkedProcessing` (прогресс-бар + список чанков)
3. Заменить inline-код в `ProcessingScreen` на вызовы новых виджетов
4. Заменить все вызовы `e.toString()` / `e.message` в UI на `e.userMessage` (через новый extension)
5. Финальный `flutter analyze` + `flutter test`

---

## Критерии готовности

- [ ] `flutter analyze` — 0 предупреждений
- [ ] `flutter test` — все тесты зелёные (включая существующие тесты `ChunkedTranscriptionController`)
- [ ] Карточка модели/языка убрана с `HomeScreen`
- [ ] Bottom nav переключает три экрана без пересоздания виджетов (`IndexedStack`)
- [ ] `SettingsScreen` сохраняет и применяет тему (`ThemeMode`) без перезапуска
- [ ] Баннер «нет ключей» появляется/исчезает реактивно при изменении ключей
- [ ] Ошибки 429/401/сеть/all-blocked показываются понятным текстом через `userMessage`
- [ ] `ProcessingScreen` использует `PipelineStepTile` и `ChunkedProgressSection`
- [ ] `groqKeyPool` не передаётся как параметр в `ProcessingScreen`

---

## Примечания для исполнителя

- Flutter path: `/opt/flutter/bin/flutter` (не в PATH)
- Для `flutter test`, `flutter analyze`, `flutter build` использовать `ctx_batch_execute` (большой вывод)
- Кодогенерация Riverpod: после добавления провайдеров запустить `dart run build_runner build --delete-conflicting-outputs`
- Если `@riverpod` аннотации не нужны (ручные провайдеры проще), можно обойтись без кодогенерации — использовать `Provider((ref) => ...)` напрямую
- Существующие тесты в `test/` не трогать без крайней необходимости
