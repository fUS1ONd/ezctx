# Walking Skeleton — ezctx Phase 1

**Created:** 2026-05-16
**Status:** draft (consumed by Plan 01)

> Тончайший возможный end-to-end слайс. Все последующие фазы строятся на этих архитектурных решениях без перепроектирования.

---

## Цель скелета

После завершения Plan 01 на устройстве работает следующий сквозной поток:
1. APK устанавливается на Android-устройство (minSdkVersion 24).
2. Открывается главный экран Home (Empty State) с шапкой «Слух», display-заголовком и upload-card (без функционала).
3. Из шапки доступна навигация на экран Settings → «API-ключи».
4. На экране API-ключей пользователь нажимает «Сохранить тестовое значение» → запись в `flutter_secure_storage` → возврат на главный экран → перезапуск → значение читается обратно (доказательство реального DB read/write).
5. CI собирает debug APK на каждый push в `main` и публикует артефакт.

Один реальный DB read/write — `flutter_secure_storage`. Одно реальное UI взаимодействие — кнопка «Сохранить» → запись ключа. Никаких заглушек на критическом пути.

---

## Архитектурные решения (фиксируются здесь, наследуются всеми фазами)

### Фреймворк и SDK

| Параметр | Значение | Источник |
|----------|---------|----------|
| Framework | Flutter (stable channel) | D-01, D-09 |
| Dart SDK | входит в Flutter, минимум `>=3.5.0 <4.0.0` | RESEARCH.md |
| Flutter версия (зафиксирована в CI) | `3.27.4` (последняя stable на 2026-05-16; обновляется одним коммитом) | RESEARCH.md A6, Claude's Discretion |
| Java для Android build | 17 (Temurin) | RESEARCH.md «Standard Stack» |
| Android minSdkVersion | **24** (Android 7.0 Nougat) — требование `ffmpeg_kit_flutter_new` | RESEARCH.md «Pitfall 2» |
| Android compileSdk / targetSdk | 34 | RESEARCH.md «Android Configuration» |
| Application ID | `com.ezctx.app` | Стандарт reverse-DNS |

### Зависимости первого дня (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.4.0
  file_picker: ^10.4.0
  flutter_secure_storage: ^9.2.4   # не v10 — breaking changes
  ffmpeg_kit_flutter_new: ^4.1.0   # форк sk3llo; оригинал arthenica архивирован
  path_provider: ^2.1.5

dev_dependencies:
  flutter_test:
    sdk: flutter
  mockito: ^5.4.4
  build_runner: ^2.4.13
  flutter_lints: ^5.0.0
```

> `ffmpeg_kit_flutter_new` добавляется в скелет (а не во Phase 2), чтобы зафиксировать `minSdkVersion 24` с первого билда и не делать миграцию позже.

### Структура директорий

```
ezctx/
├── .github/
│   └── workflows/
│       └── build-debug-apk.yml          # CI на push в main
├── android/
│   └── app/
│       ├── build.gradle.kts              # minSdkVersion 24, Java 17
│       └── src/main/
│           ├── AndroidManifest.xml       # INTERNET, Impeller meta-data
│           └── kotlin/com/ezctx/app/MainActivity.kt
├── lib/
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_constants.dart        # GROQ_API_URL, FILE_WHITELIST, MAX_SIZE
│   │   │   └── design_tokens.dart        # AppColors, AppTextStyles, AppRadius
│   │   ├── error/
│   │   │   └── app_exception.dart        # NetworkException, AuthException, ValidationException
│   │   └── storage/
│   │       └── secure_storage_service.dart   # обёртка над flutter_secure_storage
│   ├── features/
│   │   ├── settings/
│   │   │   └── api_key_repository.dart   # CRUD над одним ключом
│   │   └── transcription/                # пусто в Plan 01, заполняется Plan 03/04
│   ├── ui/
│   │   ├── widgets/
│   │   │   ├── glass_card.dart           # ClipRRect + BackdropFilter, r-card=22
│   │   │   ├── glass_tile.dart           # GlassCard, r-tile=30
│   │   │   ├── glass_icon_btn.dart       # icon button 36×36 в стекле
│   │   │   ├── primary_button.dart       # accent gradient pill
│   │   │   └── gradient_background.dart  # фон из 5 radial + linear
│   │   ├── screens/
│   │   │   ├── home_screen.dart          # Screen 1 (Plan 01 заглушка → Plan 03 наполняет)
│   │   │   ├── settings_screen.dart      # Screen 4 (Plan 01 стаб → Plan 02 наполняет)
│   │   │   ├── api_keys_screen.dart      # Plan 02
│   │   │   ├── processing_screen.dart    # Plan 04
│   │   │   └── result_screen.dart        # Plan 05
│   │   └── app.dart                       # MaterialApp, theme, routes
│   └── main.dart                          # runApp(EzCtxApp())
├── test/
│   ├── unit/
│   │   ├── secure_storage_test.dart      # Wave 0 (Plan 01)
│   │   ├── file_validator_test.dart      # Wave 0 (Plan 03)
│   │   └── groq_service_test.dart        # Wave 0 (Plan 04)
│   └── widget/
│       └── result_screen_test.dart       # Wave 0 (Plan 05)
└── pubspec.yaml
```

### Маршрутизация (минимальный роутер)

Использовать встроенный `Navigator 1.0` через именованные маршруты в `MaterialApp.routes`:

| Route | Screen | Создаётся в плане |
|-------|--------|-------------------|
| `/` | HomeScreen | 01 (заглушка) → 03 (file picker) |
| `/settings` | SettingsScreen | 01 (стаб) → 02 (список ключей) |
| `/settings/api-keys` | ApiKeysScreen | 02 |
| `/processing` | ProcessingScreen | 04 |
| `/result` | ResultScreen | 05 |

Передача данных — через `arguments: ` в `Navigator.pushNamed`. Никаких сторонних роутеров (go_router, auto_route) в v1 — оверкилл для 5 экранов.

### Состояние

`StatefulWidget` + `setState` для локального состояния экранов. Никаких Riverpod/Bloc/Provider в Phase 1 — критерий: количество экранов с разделяемым состоянием = 0 (каждый экран самодостаточен; данные передаются через `arguments`).

> Решение пересматривается, если в Phase 2 (чанкование с прогрессом) появится shared state — тогда вводится `ValueNotifier`/`ChangeNotifier` локально, без глобального DI.

### Безопасность ключей

Один источник правды: `SecureStorageService` (`lib/core/storage/secure_storage_service.dart`). Никаких других мест чтения/записи ключей. Storage key: `groq_api_keys_v1` (хранится как JSON-массив строк, готов к multi-key в Phase 3).

Конфигурация для Phase 1:
```dart
const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(),  // дефолт — EncryptedSharedPreferences через AndroidX Security
);
```

### CI/CD

GitHub Actions, `.github/workflows/build-debug-apk.yml`:
- Trigger: `push` и `pull_request` на `main` (D-05)
- Runner: `ubuntu-latest` (D-08)
- Шаги: checkout → setup-java@v4 (Temurin 17) → subosito/flutter-action@v2 (channel: stable, version: 3.27.4) → cache pub → `flutter pub get` → `flutter analyze` → `flutter test` → `flutter build apk --debug` → `actions/upload-artifact@v4` (retention 14 дней) (D-06, D-07).

### Дизайн-система

Все токены вынесены в `lib/core/constants/design_tokens.dart` (см. RESEARCH.md «Design Tokens»). Glassmorphism: `GlassCard` обязательно с `RepaintBoundary` родителем для производительности (RESEARCH.md Pitfall 4).

### Тестирование

- Framework: встроенный `flutter_test`.
- Wave 0 тесты создаются в Plan 01 как заглушки (`expect(true, isTrue)`) и наполняются в последующих планах — это сохраняет команду `flutter test` зелёной с первого билда.
- `flutter analyze` обязательно green на каждом коммите.

---

## Walking Skeleton Acceptance

Plan 01 считается завершённым, когда выполнено всё ниже:

1. `flutter --version` показывает `3.27.4` (локально и в CI).
2. `flutter analyze` выходит с кодом 0.
3. `flutter test` выходит с кодом 0 (минимум 1 тест: `secure_storage_test.dart` — round-trip write→read).
4. `flutter build apk --debug` создаёт `build/app/outputs/flutter-apk/app-debug.apk`.
5. На физическом Android-устройстве (API 24+) APK устанавливается и запускается без падений.
6. На главном экране Home виден заголовок «Расшифруй любой звук», в шапке — кнопка-шестерёнка → переход на Settings → строка «API-ключи» → экран ApiKeysScreen.
7. На экране ApiKeysScreen нажатие «Сохранить тестовое значение» (временная кнопка для скелета — удаляется в Plan 02) записывает строку `skeleton-test-key` в `flutter_secure_storage` через `SecureStorageService`; перезапуск приложения и повторное открытие экрана отображает сохранённое значение в текстовом поле.
8. Workflow `build-debug-apk.yml` отрабатывает на push в `main` и публикует артефакт `debug-apk-<sha>`.

---

## Что НЕ входит в скелет (явно)

- Реальная транскрибация (Plan 04).
- File picker и валидация (Plan 03).
- Полноценный UI ApiKeysScreen с маскированием и удалением (Plan 02).
- Pipeline-стадии и progress bar (Plan 04).
- Clipboard и SelectableText расшифровки (Plan 05).
- Pull-стиль маршрутизации, DI-контейнер, code generation.

---

*SKELETON для последующих фаз: пересматривать ТОЛЬКО при доказанной невозможности построить требование на текущей архитектуре. Изменения версии Flutter, Java, minSdkVersion — отдельный PR с обоснованием.*
