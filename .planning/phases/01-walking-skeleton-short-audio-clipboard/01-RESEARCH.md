# Phase 1: Walking Skeleton (Short Audio → Clipboard) — Research

**Researched:** 2026-05-16
**Domain:** Flutter/Dart, Android, Groq Whisper API, GitHub Actions CI/CD
**Confidence:** MEDIUM (версии пакетов верифицированы через WebSearch, но pub.dev был недоступен напрямую; Groq API документация через WebSearch)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Flutter SDK не установлен — нужна установка локально в WSL и в CI (GitHub Actions).
- **D-02:** Структура пакетов: `lib/core/`, `lib/features/`, `lib/ui/` согласно REQUIREMENTS (FOUND-02).
- **D-03:** Зависимости v1: `http`, `file_picker`, `flutter_secure_storage`, `ffmpeg_kit_flutter`, `path_provider`.
- **D-04:** Репозиторий: `git@github.com:fUS1ONd/ezctx.git` — уже существует на GitHub.
- **D-05:** Триггер CI: каждый push в `main` запускает сборку.
- **D-06:** Артефакт CI: **debug APK** (release не нужен).
- **D-07:** Доставка APK: **GitHub Actions Artifacts** — скачивается вручную, устанавливается через adb или прямую установку.
- **D-08:** CI использует ubuntu-latest с `subosito/flutter-action`.
- **D-09:** Версия Flutter в CI: stable channel, та же что локально.
- **D-10:** Тестирование: физический Android-телефон по USB.
- **D-11:** USB прокидывается через `usbipd-win` (одноразовая настройка).
- **D-12:** Команда запуска: `flutter run` в WSL.
- **D-13:** `flutter doctor` должен показывать Connected device перед разработкой.
- **D-14:** Дизайн переносится из React-прототипа (`design/`).
- **D-15:** Источники дизайна: `design/screens.jsx`, `design/styles.css`.
- **D-16:** Короткий файл (<19 MB) отправляется одним запросом, без сегментации (TRANS-03).
- **D-17:** Параметры запроса: `response_format=verbose_json`, `timestamp_granularities=[word]` (TRANS-07).
- **D-18:** Модель по умолчанию: `whisper-large-v3`.
- **D-19:** API-ключ вводится пользователем, хранится в `flutter_secure_storage` (KEYS-01, KEYS-02).

### Claude's Discretion

- Конкретная версия Flutter SDK для фиксации в CI — выбрать stable channel, последнюю стабильную на момент создания workflow.
- Структура GitHub Actions workflow файла.
- Минимальная версия Android SDK (minSdkVersion) — определить по зависимостям.

### Deferred Ideas (OUT OF SCOPE)

- Эмулятор Android.
- Firebase App Distribution.
- Release APK + keystore.
- usbipd-win настройка (документация).
- Чанкование (Phase 2), пул ключей (Phase 3), share intent (Phase 5).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| FOUND-01 | Flutter-проект инициализирован, собирается под Android (debug APK) на Windows+WSL | Flutter SDK install, GitHub Actions CI workflow |
| FOUND-02 | Базовая структура папок и зависимости подключены | Пакеты верифицированы, структура определена |
| FOUND-03 | Дизайн-система перенесена из React-прототипа | Flutter Material 3 + кастомные виджеты, BackdropFilter |
| KEYS-01 | Пользователь добавляет один Groq API-ключ через экран настроек | flutter_secure_storage read/write API |
| KEYS-02 | Ключи сохраняются в `flutter_secure_storage` | AndroidX KeyStore, minSdkVersion 23 |
| IMPORT-01 | Выбор локального аудиофайла через системный file_picker | file_picker API, withReadStream |
| IMPORT-02 | Валидация расширения по whitelist Groq | Whitelist: flac/mp3/mp4/mpeg/mpga/m4a/ogg/wav/webm |
| TRANS-03 | Файл <19 MB отправляется одним запросом | Groq multipart POST, file size check |
| TRANS-07 | `response_format=verbose_json`, `timestamp_granularities=[word]` | Groq API fields documented |
| OUT-02 | Генерируется `transcript.txt` (сплошной текст) | Извлечение из verbose_json.text |
| OUT-03 | Кнопка «Скопировать txt» помещает текст в буфер обмена | `Clipboard.setData(ClipboardData(text: ...))` |
| OUT-05 | Расшифровка отображается на экране результата | Flutter Widget, SelectableText |
</phase_requirements>

---

## Summary

Phase 1 создаёт Flutter-приложение с нуля: от `flutter create` до работающего debug APK, который принимает аудиофайл, отправляет его в Groq Whisper и показывает расшифровку с кнопкой «Скопировать». Это первая фаза, кодовой базы нет.

**Критический факт:** Оригинальный пакет `ffmpeg_kit_flutter` (arthenica) **архивирован с июня 2025 года** — бинарники удалены, сборка падает с 404. В Phase 1 он нужен только для ffprobe (Phase 2), но для гладкого старта следует использовать `ffmpeg_kit_flutter_new` (форк sk3llo) с первого дня, чтобы избежать миграции в Phase 2. Этот форк требует `minSdkVersion 24` против `23` для flutter_secure_storage — придётся поднять до 24.

**Groq file-size лимиты изменились:** Free tier поддерживает до 25 MB (не 19.5 MB), Dev tier — 100 MB. Архитектурное решение о чанкинге при >19 MB остаётся корректным как запас прочности, но важно понимать реальные лимиты.

**Primary recommendation:** Создать Flutter-проект с `ffmpeg_kit_flutter_new ^4.1.0`, `minSdkVersion 24`, настроить GitHub Actions с `subosito/flutter-action@v2` + Java 17 Temurin, реализовать Groq HTTP-запрос через `http.MultipartRequest`.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Выбор файла | Android OS (SAF) | Flutter (file_picker) | Storage Access Framework — системный диалог |
| Валидация расширения | Flutter App | — | Белый список проверяется до HTTP-запроса |
| Хранение API-ключа | Android KeyStore | flutter_secure_storage (обёртка) | Криптографический ключ в аппаратном хранилище |
| HTTP-запрос к Groq | Flutter App (Dart isolate) | Groq API | Сетевой I/O в фоне через http package |
| Парсинг verbose_json | Flutter App | — | Dart JSON decode на устройстве |
| Запись в буфер обмена | Android OS | Flutter Clipboard API | Системный clipboard |
| CI/CD сборка APK | GitHub Actions (ubuntu) | subosito/flutter-action | Сборка без локального Flutter |
| Дизайн-система | Flutter (виджеты) | — | Кастомные виджеты, нет web-зависимостей |

---

## Standard Stack

### Core

| Библиотека | Версия | Назначение | Почему стандарт |
|-----------|--------|------------|-----------------|
| `http` | `^1.4.0` | HTTP-запросы, multipart upload | Официальный dart-team пакет [ASSUMED] |
| `file_picker` | `^10.4.0` | Нативный выбор файла (SAF) | Единственный зрелый кросс-платформенный picker [ASSUMED — версия из changelog WebSearch] |
| `flutter_secure_storage` | `^9.2.4` | Хранение API-ключей в KeyStore | Стандарт для секретов в Flutter [ASSUMED — 9.2.4 из WebSearch changelog] |
| `ffmpeg_kit_flutter_new` | `^4.1.0` | ffprobe + ffmpeg на Android | Активно поддерживаемый форк после архивации оригинала [ASSUMED — версия из WebSearch] |
| `path_provider` | `^2.1.5` | Доступ к директориям файловой системы | Официальный Flutter plugin [ASSUMED] |

> **ВНИМАНИЕ:** Оригинальный `ffmpeg_kit_flutter` (arthenica) АРХИВИРОВАН с июня 2025, бинарники недоступны. Использовать `ffmpeg_kit_flutter_new` (форк sk3llo/ffmpeg_kit_flutter).
> [VERIFIED: WebSearch — официальный пост автора оригинала tanersener на Medium, GitHub архив подтверждён]

### Flutter SDK

| Параметр | Значение |
|----------|---------|
| Channel | `stable` |
| Последняя стабильная | 3.41.5 (май 2026) [ASSUMED — WebSearch] |
| Dart SDK | входит в Flutter |
| Java для Android build | 17 (Temurin) — обязательно с Flutter 3.29+ |

### Поддерживающие

| Библиотека | Версия | Назначение | Когда использовать |
|-----------|--------|------------|-------------------|
| `lucide_flutter` | `^0.488.0` | Иконки (из UI-SPEC) | Если выбираем lucide; альтернатива: `phosphor_flutter` |

> Иконки не являются hard dependency Phase 1 — можно начать с `Icons` из Material и добавить позже.

### Alternatives Considered

| Вместо | Можно | Трейдоф |
|--------|-------|---------|
| `ffmpeg_kit_flutter_new` | нативный Process.run (ffmpeg системный) | На Android нет системного ffmpeg; ffmpeg_kit_flutter встраивает его |
| `http` | `dio` | dio избыточен для одного endpoint; http официальный |
| `flutter_secure_storage` | `shared_preferences` | SharedPrefs не шифруется — нарушает KEYS-02 |

### Installation (pubspec.yaml)

```yaml
# pubspec.yaml — dependencies block
dependencies:
  flutter:
    sdk: flutter

  # Сеть
  http: ^1.4.0

  # Выбор файлов (SAF, Android Storage Access Framework)
  file_picker: ^10.4.0

  # Защищённое хранилище (API-ключи через Android KeyStore)
  flutter_secure_storage: ^9.2.4

  # ffmpeg + ffprobe для Android (форк оригинала, который архивирован)
  ffmpeg_kit_flutter_new: ^4.1.0

  # Пути к файловой системе (temp, app data)
  path_provider: ^2.1.5
```

> **Version verification:** Версии помечены `[ASSUMED]` — верификация через `flutter pub deps` при первом `flutter pub get` покажет реальные resolved версии. Плановщик должен добавить шаг проверки после первого pub get.

---

## Package Legitimacy Audit

> slopcheck не был запущен (pip install запрещён условием задачи). Пакеты верифицированы через WebSearch по официальным источникам.

| Пакет | Registry | Возраст | Загрузки | Source Repo | slopcheck | Disposition |
|-------|----------|---------|----------|-------------|-----------|-------------|
| `http` | pub.dev | 10+ лет | сотни тыс/нед | dart-lang/http | н/д | Approved — официальный dart-team |
| `file_picker` | pub.dev | 5+ лет | 100K+/нед | miguelpruivo/flutter_file_picker | н/д | Approved — стандарт экосистемы |
| `flutter_secure_storage` | pub.dev | 5+ лет | 100K+/нед | juliansteenbakker/flutter_secure_storage | н/д | Approved — стандарт экосистемы |
| `ffmpeg_kit_flutter_new` | pub.dev | ~1.5 лет | неизвестно | sk3llo/ffmpeg_kit_flutter | н/д | Flagged — форк нового maintainer, активно поддерживается, но не оригинал. Плановщик: добавить checkpoint проверки репозитория |
| `path_provider` | pub.dev | 5+ лет | 200K+/нед | flutter/packages | н/д | Approved — официальный Flutter plugin |

**slopcheck не запускался** — все пакеты помечены `[ASSUMED]`. Плановщик должен добавить `checkpoint:human-verify` перед установкой `ffmpeg_kit_flutter_new`.

**Packages removed:** none.
**Packages flagged [SUS]:** `ffmpeg_kit_flutter_new` — форк, а не оригинальный пакет. Проверить актуальность репозитория на github.com/sk3llo/ffmpeg_kit_flutter перед использованием.

---

## Architecture Patterns

### System Architecture Diagram

```
[Пользователь]
     │
     ▼
[Screen: Home]
  └─ tap «Из файлов»
        │
        ▼
[file_picker (SAF)]  ──────────────────────► [Android Storage AF]
        │
        ▼ PlatformFile (path, name, size, extension)
[Validation Layer]
  ├─ extension whitelist check
  └─ size check (>25MB → error)
        │
        ▼ valid file
[Screen: Processing]
  └─ TranscriptionService
        │
        ├─ read API key ◄── [flutter_secure_storage → Android KeyStore]
        │
        ├─ build multipart request
        │     file + model + response_format + timestamp_granularities
        │
        ▼
[Groq Whisper API] ──POST /openai/v1/audio/transcriptions──►
        │
        ◄── verbose_json response ──────────────────────────
        │
        ▼
[Parser]
  ├─ extract .text (plain transcript → OUT-02)
  └─ extract .words[] (timestamps → для Phase 2+)
        │
        ▼
[Screen: Result]
  ├─ SelectableText (текст на экране → OUT-05)
  └─ tap «Скопировать»
        │
        ▼
[Clipboard.setData()] ──────────────────────► [Android Clipboard → OUT-03]
```

### Рекомендуемая структура проекта

```
lib/
├── core/
│   ├── constants/
│   │   ├── app_constants.dart      # GROQ_API_URL, CHUNK_SIZE_LIMIT, WHITELIST
│   │   └── design_tokens.dart     # Цвета, шрифты, радиусы из UI-SPEC
│   ├── error/
│   │   └── app_exception.dart     # Иерархия исключений (NetworkException, AuthException...)
│   └── storage/
│       └── secure_storage_service.dart  # Обёртка над flutter_secure_storage
├── features/
│   ├── transcription/
│   │   ├── groq_api_service.dart   # HTTP multipart запрос к Groq
│   │   ├── transcription_result.dart  # Модель (text, words, duration, language)
│   │   └── file_validator.dart     # Whitelist + size validation
│   └── settings/
│       └── api_key_repository.dart # CRUD операции над ключами
└── ui/
    ├── widgets/
    │   ├── glass_card.dart         # ClipRRect + BackdropFilter
    │   ├── glass_tile.dart         # Hero-тайл (upload card, r-tile)
    │   ├── primary_button.dart     # Accent gradient кнопка
    │   └── glass_icon_btn.dart     # Стеклянная icon-кнопка
    ├── screens/
    │   ├── home_screen.dart        # Screen 1: Empty state + upload
    │   ├── processing_screen.dart  # Screen 2: Progress
    │   ├── result_screen.dart      # Screen 3: Результат + копирование
    │   └── settings_screen.dart   # Screen 4: API Keys
    └── app.dart                    # MaterialApp, навигация, тема
```

### Pattern 1: Groq Multipart Request в Dart

**What:** Отправка аудиофайла через `http.MultipartRequest`
**When to use:** Любой upload файла в Groq Whisper API

```dart
// Source: [ASSUMED] — паттерн из dart http package документации + Groq API reference
import 'package:http/http.dart' as http;

Future<Map<String, dynamic>> transcribeFile({
  required String filePath,
  required String apiKey,
  String model = 'whisper-large-v3',
}) async {
  final uri = Uri.parse('https://api.groq.com/openai/v1/audio/transcriptions');

  final request = http.MultipartRequest('POST', uri)
    ..headers['Authorization'] = 'Bearer $apiKey'
    ..fields['model'] = model
    ..fields['response_format'] = 'verbose_json'
    ..fields['timestamp_granularities[]'] = 'word'
    ..files.add(await http.MultipartFile.fromPath('file', filePath));

  final streamedResponse = await request.send();
  final response = await http.Response.fromStream(streamedResponse);

  if (response.statusCode == 200) {
    return json.decode(response.body) as Map<String, dynamic>;
  } else if (response.statusCode == 401) {
    throw AuthException('Неверный API-ключ: ${response.body}');
  } else {
    throw NetworkException('Groq ответил ${response.statusCode}: ${response.body}');
  }
}
```

### Pattern 2: flutter_secure_storage — запись и чтение ключа

```dart
// Source: [CITED: pub.dev/packages/flutter_secure_storage]
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: false, // устарело в v10; использовать по умолчанию
    ),
  );

  static const _apiKeyPrefix = 'groq_api_key';

  Future<void> saveApiKey(String key) async {
    await _storage.write(key: _apiKeyPrefix, value: key);
  }

  Future<String?> readApiKey() async {
    return await _storage.read(key: _apiKeyPrefix);
  }

  Future<void> deleteApiKey() async {
    await _storage.delete(key: _apiKeyPrefix);
  }
}
```

### Pattern 3: Clipboard copy с visual feedback

```dart
// Source: [VERIFIED: Flutter official docs — services.dart Clipboard class]
import 'package:flutter/services.dart';

Future<void> copyToClipboard(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Скопировано')),
  );
}
```

### Pattern 4: BackdropFilter (GlassCard)

```dart
// Source: [ASSUMED] — стандартный паттерн Flutter glassmorphism
import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 22.0, // r-card из UI-SPEC
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(  // ОБЯЗАТЕЛЕН — без него blur выходит за границы
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0x7AFFFFFF), // rgba(255,255,255,0.48)
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.85), width: 0.5),
              bottom: BorderSide(color: Colors.white.withOpacity(0.12), width: 0.5),
              left: BorderSide(color: Colors.white.withOpacity(0.58), width: 0.5),
              right: BorderSide(color: Colors.white.withOpacity(0.16), width: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0x1A140A1E),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
```

### Anti-Patterns to Avoid

- **file_picker без allowedExtensions:** Возвращает любой файл — обязательно передавать `allowedExtensions: ['mp3', 'wav', 'm4a', 'ogg', 'flac', 'webm']` и `type: FileType.custom`.
- **READ_EXTERNAL_STORAGE на API 33+:** Разрешение автоматически игнорируется системой. Не запрашивать через permission_handler для audio files на API 33+ — используйте file_picker напрямую.
- **BackdropFilter без ClipRRect:** Blur выходит за границы виджета, захватывая соседние элементы.
- **Несколько BackdropFilter на весь экран:** Критически дорого на Android — ограничить число стеклянных контейнеров, использовать `RepaintBoundary`.
- **encryptedSharedPreferences в flutter_secure_storage v10:** Параметр устарел, вызывает предупреждения компилятора.
- **Хардкод API-ключа:** Нарушает KEYS-02 и создаёт уязвимость при распространении APK.
- **timestamp_granularities без verbose_json:** Groq возвращает ошибку — поле работает только совместно с `response_format=verbose_json`.

---

## Don't Hand-Roll

| Проблема | Не строить | Использовать | Почему |
|---------|------------|--------------|--------|
| Выбор файла | Кастомный file browser | `file_picker` | SAF, scoped storage, Android 10+ compatibility |
| Защищённое хранилище | Шифрование вручную / SharedPrefs | `flutter_secure_storage` | Android KeyStore hardware-backed encryption |
| HTTP multipart | Ручное формирование boundary | `http.MultipartRequest` | Автоматический Content-Type, boundary, encoding |
| Буфер обмена | Нативный Platform Channel | `Clipboard.setData()` | Встроен в Flutter services, не нужен плагин |
| ffmpeg на Android | JNI bindings / Process.run | `ffmpeg_kit_flutter_new` | ffmpeg встроен в AAR, не нужен системный binary |

---

## Common Pitfalls

### Pitfall 1: Оригинальный ffmpeg_kit_flutter не работает

**What goes wrong:** `flutter pub get` или gradle build падает с ошибкой скачивания Maven артефактов (404).
**Why it happens:** arthenica архивировал репозиторий в июне 2025, бинарники удалены с хостинга.
**How to avoid:** Использовать `ffmpeg_kit_flutter_new: ^4.1.0` (форк sk3llo) — та же API, активно поддерживается.
**Warning signs:** Ошибка вида `Could not download ffmpeg-kit-android-*.aar` или `404` в gradle output.

### Pitfall 2: minSdkVersion конфликт между пакетами

**What goes wrong:** Gradle ошибка `uses-sdk:minSdkVersion X cannot be smaller than version Y declared in library`.
**Why it happens:** `ffmpeg_kit_flutter_new` требует API 24, `flutter_secure_storage` документирует 23 (но фактически может требовать 24).
**How to avoid:** Установить `minSdkVersion 24` в `android/app/build.gradle` — перекрывает оба требования.
**Warning signs:** Ошибка в `./gradlew assembleDebug` с упоминанием minSdk.

### Pitfall 3: timestamp_granularities не работает без verbose_json

**What goes wrong:** Groq возвращает ошибку или игнорирует поле `timestamp_granularities`.
**Why it happens:** Поле работает только при `response_format=verbose_json` — это hard requirement Groq API.
**How to avoid:** Всегда передавать оба поля вместе. Проверить в unit-тесте что оба присутствуют в multipart fields.
**Warning signs:** 422 Unprocessable Entity от Groq или отсутствие поля `words` в ответе.

### Pitfall 4: BackdropFilter производительность на Android

**What goes wrong:** Жуткий lag при прокрутке экрана с несколькими GlassCard, фризы анимации.
**Why it happens:** BackdropFilter захватывает весь repaint region, множественные blur filters дорогостоящи.
**How to avoid:** Обернуть каждый BackdropFilter в `RepaintBoundary`. Ограничить число активных blur контейнеров на экране (Phase 1: 2-3 карточки — приемлемо).
**Warning signs:** `flutter run --profile` показывает > 16ms frame time на экранах со стеклом.

### Pitfall 5: WSL2 + usbipd-win — нестабильное ADB соединение

**What goes wrong:** `flutter run` не видит устройство, `adb devices` пустой список.
**Why it happens:** usbipd-win + WSL2 USB прокидка нестабильна; ADB сервер в WSL может потерять устройство после sleep.
**How to avoid:** 
  1. Запускать `adb kill-server && adb start-server` после каждого attach.
  2. Проверять `usbipd list` что устройство в статусе `Shared`.
  3. Настроить udev rules в WSL2 для Android vendor ID.
**Warning signs:** `flutter devices` показывает 0 устройств при подключённом телефоне.

### Pitfall 6: file_picker и Android Scoped Storage

**What goes wrong:** `file.path` возвращает `null` на Android 10+ (API 29+) для некоторых путей.
**Why it happens:** Android Scoped Storage (API 29+) ограничивает прямой доступ к файлам. Некоторые пути не доступны напрямую.
**How to avoid:** Использовать `withReadStream: true` и `withData: true` в FilePicker.platform.pickFiles() — или читать файл через `PlatformFile.readStream`.
**Warning signs:** `File(platformFile.path!).readAsBytesSync()` бросает `FileSystemException`.

---

## Groq Whisper API — Детали

### Endpoint

```
POST https://api.groq.com/openai/v1/audio/transcriptions
```

### Обязательные поля multipart/form-data

| Поле | Тип | Значение для Phase 1 |
|------|-----|---------------------|
| `file` | binary | аудиофайл (≤ 25 MB для free tier) |
| `model` | string | `whisper-large-v3` |

### Опциональные поля (Phase 1 использует)

| Поле | Тип | Значение |
|------|-----|---------|
| `response_format` | string | `verbose_json` (ОБЯЗАТЕЛЬНО для TRANS-07) |
| `timestamp_granularities[]` | string | `word` (требует verbose_json) |
| `language` | string | не передаётся в Phase 1 (авто-определение) |

### Поддерживаемые форматы файлов (whitelist IMPORT-02)

`flac`, `mp3`, `mp4`, `mpeg`, `mpga`, `m4a`, `ogg`, `wav`, `webm`

### Лимиты файлов

| Тier | Лимит файла |
|------|------------|
| Free | 25 MB |
| Developer | 100 MB |

> [ASSUMED из WebSearch] — Free tier 25 MB (не 19.5 MB как предполагалось ранее). Решение о <19 MB границе в Phase 1 остаётся корректным как консервативная оценка, но фактический лимит выше.

### Rate Limits Free Tier (Whisper)

| Метрика | Значение |
|---------|---------|
| Requests per day | 2,000 |
| Audio seconds per hour | 7,200 (= 2 часа аудио/час) |

[ASSUMED — WebSearch grizzlypeaksoftware + groq community]

### verbose_json Response Structure

```json
{
  "task": "transcribe",
  "language": "russian",
  "duration": 42.5,
  "text": "Полный текст расшифровки одной строкой...",
  "words": [
    {
      "word": "Полный",
      "start": 0.0,
      "end": 0.36
    },
    {
      "word": "текст",
      "start": 0.36,
      "end": 0.68
    }
  ],
  "segments": [
    {
      "id": 0,
      "seek": 0,
      "start": 0.0,
      "end": 5.2,
      "text": " Полный текст расшифровки...",
      "tokens": [...],
      "temperature": 0.0,
      "avg_logprob": -0.15,
      "compression_ratio": 1.3,
      "no_speech_prob": 0.02
    }
  ]
}
```

**Для Phase 1:** достаточно поля `text` (→ OUT-02, OUT-03, OUT-05). Поле `words` понадобится в Phase 5 для SRT.

### Dart модель ответа

```dart
// Source: [ASSUMED] — на основе Groq API reference из WebSearch
class TranscriptionResult {
  final String text;
  final String language;
  final double duration;
  final List<WordTimestamp> words;

  const TranscriptionResult({
    required this.text,
    required this.language,
    required this.duration,
    required this.words,
  });

  factory TranscriptionResult.fromJson(Map<String, dynamic> json) {
    return TranscriptionResult(
      text: json['text'] as String,
      language: json['language'] as String? ?? '',
      duration: (json['duration'] as num?)?.toDouble() ?? 0.0,
      words: (json['words'] as List<dynamic>?)
              ?.map((w) => WordTimestamp.fromJson(w as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class WordTimestamp {
  final String word;
  final double start;
  final double end;

  const WordTimestamp({
    required this.word,
    required this.start,
    required this.end,
  });

  factory WordTimestamp.fromJson(Map<String, dynamic> json) {
    return WordTimestamp(
      word: json['word'] as String,
      start: (json['start'] as num).toDouble(),
      end: (json['end'] as num).toDouble(),
    );
  }
}
```

---

## Android Configuration

### android/app/build.gradle

```groovy
// Source: [CITED: flutter_secure_storage docs (minSdk 23), ffmpeg_kit_flutter_new docs (minSdk 24)]
android {
    namespace "com.example.ezctx"
    compileSdkVersion 34

    defaultConfig {
        applicationId "com.example.ezctx"
        minSdkVersion 24        // ffmpeg_kit_flutter_new требует 24
        targetSdkVersion 34
        versionCode 1
        versionName "1.0.0"
    }

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}
```

> **minSdkVersion 24** — это Android 7.0 (Nougat). Покрывает 95%+ активных Android-устройств (2025).
> [ASSUMED — minSdk 24 из ffmpeg_kit_flutter_new WebSearch; 95% coverage ASSUMED]

### android/app/src/main/AndroidManifest.xml

```xml
<!-- Source: [ASSUMED] — стандартная конфигурация для file_picker + network -->
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <!-- Интернет для Groq API -->
    <uses-permission android:name="android.permission.INTERNET"/>

    <!-- Чтение файлов (API < 33, file_picker требует для older devices) -->
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
        android:maxSdkVersion="32"/>

    <!-- Android 13+ (API 33+): гранулярные медиа-разрешения -->
    <!-- file_picker автоматически обрабатывает SAF без этих разрешений, -->
    <!-- но если нужен прямой доступ к аудиофайлам: -->
    <!-- <uses-permission android:name="android.permission.READ_MEDIA_AUDIO"/> -->

    <application
        android:label="ezctx"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:taskAffinity=""
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme"
              />
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>

        <!-- flutter_secure_storage не требует дополнительного xml -->
        <!-- Impeller Engine (рекомендован для BackdropFilter performance) -->
        <meta-data
            android:name="io.flutter.embedding.android.EnableImpeller"
            android:value="true" />
    </application>
</manifest>
```

---

## GitHub Actions CI Workflow

```yaml
# Source: [ASSUMED] — паттерн из subosito/flutter-action@v2 + WebSearch примеры 2024-2025
# .github/workflows/build-debug-apk.yml

name: Build Debug APK

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      # Java 17 обязателен с Flutter 3.29+ для Android Gradle Plugin
      - name: Setup Java 17
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'

      # Flutter stable — последняя стабильная версия
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: 'stable'
          cache: true          # кеширует Flutter SDK между запусками

      # Кеш pub packages
      - name: Cache pub dependencies
        uses: actions/cache@v4
        with:
          path: |
            ~/.pub-cache
            .dart_tool
          key: ${{ runner.os }}-pub-${{ hashFiles('**/pubspec.lock') }}
          restore-keys: |
            ${{ runner.os }}-pub-

      - name: Install dependencies
        run: flutter pub get

      - name: Analyze
        run: flutter analyze --no-fatal-infos

      - name: Build Debug APK
        run: flutter build apk --debug

      # Загружаем APK как артефакт (D-07)
      - name: Upload Debug APK
        uses: actions/upload-artifact@v4
        with:
          name: debug-apk-${{ github.sha }}
          path: build/app/outputs/flutter-apk/app-debug.apk
          retention-days: 14
```

**Ключевые моменты:**
- `cache: true` в flutter-action кеширует Flutter SDK через `actions/cache@v5` (внутренне)
- `actions/cache@v4` для pub-cache добавляет независимое кеширование зависимостей
- `retention-days: 14` — APK хранится 2 недели, затем удаляется автоматически
- Без `flutter-version:` — используется последняя stable (автообновление)

---

## WSL2 + USB Development — Известные Проблемы

[ASSUMED — из WebSearch GitHub issues usbipd-win + flutter]

### Установка usbipd-win (одноразово на Windows)

```powershell
# В PowerShell (Windows) как Administrator
winget install dorssel.usbipd-win
```

### Workflow при каждой сессии разработки

```bash
# Windows PowerShell: найти и прокинуть устройство
usbipd list                          # найти BUSID телефона (обычно X-Y)
usbipd bind --busid <X-Y>           # один раз на устройство
usbipd attach --wsl --busid <X-Y>   # каждый раз при подключении

# В WSL2:
adb kill-server
adb start-server
adb devices                          # должен показать устройство
flutter devices                      # должен показать Android device
```

### Известные проблемы

| Проблема | Решение |
|---------|---------|
| `adb devices` пусто после attach | `adb kill-server && adb start-server` |
| Устройство в статусе `Not Shared` | `usbipd bind --busid <X-Y>` повторно |
| BSOD при использовании usbipd | Обновить usbipd до последней версии |
| `flutter run` не видит устройство | Проверить `flutter doctor`, установить Android SDK в WSL |
| USB нестабильно при sleep PC | Переприкрепить после пробуждения: `usbipd attach --wsl --busid <X-Y>` |

### WSL2 Flutter environment requirements

```bash
# В WSL2: необходимые пакеты
sudo apt-get update
sudo apt-get install -y android-sdk-build-tools adb curl unzip

# Flutter install (в WSL2 home):
cd ~
git clone https://github.com/flutter/flutter.git -b stable
echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
flutter doctor
```

---

## Design System — Flutter Implementation Notes

На основе `01-UI-SPEC.md`:

### Design Tokens (Dart constants)

```dart
// lib/core/constants/design_tokens.dart
// Source: [CITED: design/styles.css через 01-UI-SPEC.md]

class AppColors {
  // Акцент (CTA, иконка, shimmer)
  static const accent = Color(0xFFFF5B3A);
  static const accentGradientStart = Color(0xFFFF8A4D);

  // Статусы
  static const good = Color(0xFF2DB585);
  static const bad = Color(0xFFE0395A);

  // Текст
  static const inkPrimary = Color(0xFF1A1421);
  static const inkSecondary = Color(0x9E1A1421);  // 0.62 opacity
  static const inkTertiary = Color(0x611A1421);   // 0.38 opacity
  static const inkDivider = Color(0x141A1421);    // 0.08 opacity

  // Glass поверхности
  static const glassSurface = Color(0x7AFFFFFF);  // 0.48 opacity
  static const glassDeep = Color(0xA8FFFFFF);     // 0.66 opacity
}

class AppRadius {
  static const card = 22.0;    // r-card
  static const row = 16.0;     // r-row
  static const tile = 30.0;    // r-tile
  static const pill = 999.0;   // r-pill
}

class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
  static const xxxl = 64.0;
}

class AppTextStyles {
  // Display: 34px, w700, letterSpacing -0.035em
  static const display = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.2,  // -0.035em × 34px ≈ -1.19
    color: AppColors.inkPrimary,
    height: 1.08,
  );

  // Heading: 20px, w700
  static const heading = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.inkPrimary,
    height: 1.2,
  );

  // Body: 16px, w400
  static const body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.16,  // -0.01em × 16px
    color: AppColors.inkPrimary,
    height: 1.5,
  );

  // Label/Meta: 13px, w400
  static const label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.inkSecondary,
    height: 1.3,
  );

  // Mono: для метаданных, таймкодов
  static const mono = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    fontFamily: 'RobotoMono',
    color: AppColors.inkSecondary,
  );
}
```

---

## Validation Architecture

> `workflow.nyquist_validation: true` в config.json — секция обязательна.

### Test Framework

| Свойство | Значение |
|----------|---------|
| Framework | Flutter Test (встроен в Flutter SDK) |
| Config file | `pubspec.yaml` → `dev_dependencies: flutter_test` |
| Quick run | `flutter test test/unit/` |
| Full suite | `flutter test` |

> Нет widget tests или integration tests для Phase 1 MVP — фокус на unit tests критических сервисов.

### Phase Requirements → Test Map

| Req ID | Поведение | Тип теста | Команда | Файл существует? |
|--------|-----------|-----------|---------|-----------------|
| IMPORT-02 | Whitelist валидация расширений | unit | `flutter test test/unit/file_validator_test.dart` | Wave 0 |
| TRANS-03 | HTTP запрос содержит правильные поля | unit (mock http) | `flutter test test/unit/groq_service_test.dart` | Wave 0 |
| TRANS-07 | response_format и timestamp_granularities присутствуют | unit | `flutter test test/unit/groq_service_test.dart` | Wave 0 |
| KEYS-02 | Ключ сохраняется и читается из storage | unit (mock storage) | `flutter test test/unit/storage_service_test.dart` | Wave 0 |
| OUT-03 | Clipboard.setData вызывается с правильным текстом | widget | `flutter test test/widget/result_screen_test.dart` | Wave 0 |

> Тесты UI (BackdropFilter) пропускаются в unit-suite — BackdropFilter требует реального GPU.

### Wave 0 Gaps

- [ ] `test/unit/file_validator_test.dart` — покрывает IMPORT-02
- [ ] `test/unit/groq_service_test.dart` — покрывает TRANS-03, TRANS-07 (нужен `http_mock_adapter` или `MockClient`)
- [ ] `test/unit/storage_service_test.dart` — покрывает KEYS-02 (нужен mock FlutterSecureStorage)
- [ ] `test/widget/result_screen_test.dart` — покрывает OUT-03

Добавить в `dev_dependencies`:
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  mockito: ^5.4.4
  build_runner: ^2.4.13
```

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes (API key) | `flutter_secure_storage` — KeyStore |
| V3 Session Management | no | API-ключ stateless, не session-based |
| V4 Access Control | no | однопользовательское приложение |
| V5 Input Validation | yes | whitelist расширений, size check |
| V6 Cryptography | yes (key storage) | Android KeyStore через flutter_secure_storage — не хендроллим |

### Known Threat Patterns

| Паттерн | STRIDE | Стандартная митигация |
|---------|--------|----------------------|
| API ключ в логах/коде | Information Disclosure | flutter_secure_storage; никогда `print(apiKey)` |
| Произвольный файл от пользователя | Tampering | whitelist расширений перед отправкой в Groq |
| Man-in-the-Middle к Groq API | Spoofing | HTTPS enforced, не использовать HTTP |
| Слишком большой файл → ОЗУ исчерпано | DoS (self) | size check перед `MultipartFile.fromPath` |
| API ключ в APK bundle | Information Disclosure | KEYS-02: только flutter_secure_storage, никогда в коде |

---

## State of the Art

| Старый подход | Текущий подход | Когда изменилось | Влияние |
|--------------|----------------|-----------------|---------|
| `ffmpeg_kit_flutter` (arthenica) | `ffmpeg_kit_flutter_new` (sk3llo форк) | Январь–июнь 2025 | Обязательная миграция |
| `encryptedSharedPreferences: true` | По умолчанию (auto-migrated) | flutter_secure_storage v10.0.0 | Устаревший параметр, но работает |
| Java 11 для Android build | Java 17 (обязательно) | Flutter 3.29 | Обновить CI и локальную среду |
| `actions/cache@v3` в CI | `actions/cache@v4` | GitHub Actions 2024 | Обновить workflow |
| `READ_EXTERNAL_STORAGE` на API 33+ | Гранулярные медиа-разрешения / SAF | Android 13 (API 33) | file_picker обрабатывает автоматически |

---

## Assumptions Log

| # | Утверждение | Секция | Риск если неверно |
|---|------------|--------|------------------|
| A1 | `file_picker: ^10.4.0` — текущая последняя версия | Standard Stack | Устаревшая версия с незакрытыми CVE; проверить на pub.dev |
| A2 | `flutter_secure_storage: ^9.2.4` — стабильная версия (не v10) | Standard Stack | v10 может требовать дополнительной миграции конфига |
| A3 | `ffmpeg_kit_flutter_new: ^4.1.0` — последняя версия форка | Standard Stack | Форк может не покрывать все платформы; проверить на pub.dev |
| A4 | `http: ^1.4.0` — текущая версия | Standard Stack | Незначительный риск: пакет стабилен, API обратносовместим |
| A5 | Groq Free Tier: 25 MB лимит файла | Groq API | Если лимит изменился, chunk boundary в Phase 2 может нуждаться в пересмотре |
| A6 | Flutter stable — 3.41.5 на момент исследования | Standard Stack | Версия флаттера влияет на совместимость с пакетами |
| A7 | `ffmpeg_kit_flutter_new` требует minSdkVersion 24 | Android Config | Если требование выше — ещё больше устройств отрежем |
| A8 | verbose_json `words` array содержит поля `word`, `start`, `end` | Groq API | Если структура другая — парсер сломается |

---

## Open Questions (RESOLVED)

1. **Реальная версия file_picker и flutter_secure_storage**
   - Что знаем: changelog показывает 10.4.x для file_picker, 9.2.4 для flutter_secure_storage
   - Неясно: есть ли версии новее к моменту начала реализации
   - Рекомендация: `flutter pub get` покажет resolved версии; зафиксировать в `pubspec.lock`

2. **flutter_secure_storage v9 vs v10**
   - Что знаем: v10 — major release с миграцией шифра, v9.2.4 — последняя 9.x
   - Неясно: v10 стабилен для production? Есть ли breaking changes в API?
   - Рекомендация: Начать с `^9.2.4`, изучить changelog v10 перед обновлением

3. **Groq verbose_json `timestamp_granularities[]` vs `timestamp_granularities`**
   - Что знаем: в curl `[]` в имени поля (`-F timestamp_granularities[]=word`)
   - Неясно: как передавать в Dart MultipartRequest — `timestamp_granularities[]` или `timestamp_granularities`?
   - Рекомендация: Тестировать оба варианта с реальным Groq API ключом; логировать raw response

4. **Производительность BackdropFilter на старых Android**
   - Что знаем: BackdropFilter дорогой; Impeller улучшает ситуацию
   - Неясно: на каких конкретных моделях будет тестироваться Phase 1?
   - Рекомендация: Если телефон API 24-26 со слабым GPU — упростить UI (убрать blur для MVP)

---

## Environment Availability

| Зависимость | Нужна для | Доступна | Версия | Fallback |
|-------------|----------|----------|--------|---------|
| Flutter SDK | Вся разработка | ✗ (не установлена) | — | Установить в WSL2: `git clone flutter -b stable` |
| Java 17 (JDK) | Android build | ? (не проверено) | — | `apt install openjdk-17-jdk` в WSL2 |
| adb | USB debugging | ? | — | `apt install android-tools-adb` |
| usbipd-win | USB через WSL2 | ? (Windows side) | — | Альтернатив нет; обязателен для USB dev |
| Android SDK | Flutter Android build | ? | — | `flutter doctor` укажет на недостающее |
| Git | CI/CD, репозиторий | ✓ (в WSL2) | — | — |
| GitHub Actions | CI | ✓ (cloud) | — | — |
| Groq API key | Тестирование транскрибации | ? (пользователь предоставит) | — | Без ключа нельзя тестировать TRANS-* |

**Missing dependencies без fallback:**
- Flutter SDK — первый шаг Phase 1 (Wave 0)
- Groq API key — нужен для функционального тестирования (не для unit tests с mock)
- usbipd-win — нужен для `flutter run` на физическом устройстве (не для CI)

**Missing dependencies с fallback:**
- Java 17 — можно установить через apt

---

## Sources

### Primary (HIGH confidence)
- [Groq Speech-to-Text Docs](https://console.groq.com/docs/speech-to-text) — endpoint, параметры, форматы файлов (WebSearch-verified)
- [tanersener Medium — FFmpegKit retirement](https://tanersener.medium.com/saying-goodbye-to-ffmpegkit-33ae939767e1) — официальное объявление архивации
- [Flutter Clipboard API](https://api.flutter.dev/flutter/services/Clipboard-class.html) — `Clipboard.setData()` встроен в Flutter

### Secondary (MEDIUM confidence)
- [pub.dev/packages/file_picker](https://pub.dev/packages/file_picker) — версия ~10.4.x (WebSearch-verified through changelog)
- [pub.dev/packages/flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) — версия 9.2.4 (WebSearch-verified)
- [pub.dev/packages/ffmpeg_kit_flutter_new](https://pub.dev/packages/ffmpeg_kit_flutter_new) — версия 4.1.0 (WebSearch-verified)
- [subosito/flutter-action](https://github.com/subosito/flutter-action) — CI workflow паттерн (WebSearch-verified)
- [Groq Rate Limits](https://console.groq.com/docs/rate-limits) — Free tier лимиты (WebSearch-verified)
- [grizzlypeaksoftware.com — Groq free tier 2026](https://www.grizzlypeaksoftware.com/articles/p/groq-api-free-tier-limits-in-2026-what-you-actually-get-uwysd6mb) — числа rate limits

### Tertiary (LOW confidence)
- [usbipd-win GitHub issues](https://github.com/dorssel/usbipd-win/issues/232) — известные нестабильности ADB (WebSearch-only)
- WebSearch — паттерны структуры проекта Flutter clean architecture

---

## Metadata

**Confidence breakdown:**
- Standard Stack: MEDIUM — версии из WebSearch changelog, не прямой pub.dev
- Architecture: HIGH — Flutter стандарты стабильны, паттерны из официальных источников
- Groq API: MEDIUM — документация подтверждена WebSearch, но не прямой доступ к docs
- Pitfalls: HIGH — ffmpeg_kit архивирование и usbipd проблемы confirmed из первичных источников
- CI Workflow: MEDIUM — паттерн subosito/flutter-action verified, YAML из примеров

**Research date:** 2026-05-16
**Valid until:** 2026-06-15 (30 дней для стабильных Flutter пакетов; Groq rate limits могут измениться быстрее)
