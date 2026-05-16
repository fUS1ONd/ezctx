# ezctx — решения по стеку

## Что делаем
Кроссплатформенное приложение для извлечения контекста из аудио для нейросетей (распознавание речи, расшифровка, передача в LLM).

## Стек
**Flutter (Dart)** — один кодбейз на все целевые платформы.

Причины:
- Одинаковый UI на Android/iOS/Windows без переписывания.
- Зрелый `ffmpeg_kit_flutter` для работы со звуком на мобилках.
- Дизайн уже есть в виде React-прототипа (`design/`) — переносится во Flutter-виджеты почти механически.
- Большая экосистема пакетов: запись звука, file_picker, http, on-device inference (tflite/onnx).

## Порядок релизов
1. **Android** — первым.
   - Собирается прямо с Windows + WSL, без Mac.
   - Раздача: APK напрямую → бета через Firebase App Distribution → Google Play ($25 разово).
2. **Windows** — потом, как десктоп-версия.
   - `flutter build windows` → `.exe`.
   - Layout адаптируется под широкий экран (sidebar, drag-and-drop файлов).
   - На десктопе вместо `ffmpeg_kit` — системный `ffmpeg.exe` через `Process.run`.
   - Раздача: `.exe` + Inno Setup, либо Microsoft Store.
3. **iOS** — опционально, позже.
   - Требует macOS (Mac mini или Codemagic CI) и Apple Developer Program ($99/год).
   - Раздача через TestFlight / App Store.

## Структура проекта (план)
```
~/projects/ezctx/
├── design/         # исходный React-прототип дизайна
├── app/            # Flutter-проект (создадим)
└── DECISIONS.md    # этот файл
```
