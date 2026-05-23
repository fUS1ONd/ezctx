# Performance — Scroll Jank Fixes

**Branch:** `perf/scroll-jank-fixes` (уже создана и checked-out)
**Дата:** 2026-05-23
**Документ самодостаточен** — рассчитан на выполнение AI-агентом в чистом контексте.

> **Цель:** убрать просадки FPS при прокрутке всех экранов **без визуальных изменений**.

---

## 0. Контекст и инварианты проекта (читай первым)

### 0.1 О проекте
**ezctx** — Flutter-приложение под Android (старт с Android, потом iOS/desktop), локально извлекает текст из аудио через Groq Whisper API. Состояние ветки `main` — рабочее, на нём прохождение основного пути уже отлажено.

### 0.2 Жёсткие правила выполнения (из CLAUDE.md)

**Пути:**
- Flutter/Dart **не в PATH**. Использовать `/opt/flutter/bin/flutter` и `/opt/flutter/bin/dart`.
- Корень проекта: `/root/projects/ezctx`.

**Context-mode (критично!):**
Для команд с большим выводом **ВСЕГДА** использовать `mcp__plugin_context-mode_context-mode__ctx_batch_execute` или `ctx_execute`. **Запрещено** запускать через Bash напрямую:
- `flutter test`, `flutter analyze`, `flutter build`, `flutter pub get`
- `find`, `grep` на большом дереве файлов
- `git log`, `git diff` с большим выводом

Bash разрешён только для: `git add/commit/push/checkout`, `mkdir`, `mv`, `rm`, `cp`, навигации.

**Язык:**
- Комментарии в коде — на русском.
- Коммиты — на русском, **без указания авторства Claude** в сообщениях.

**Запуск устройства невозможен в WSL.** Этап «замеры на устройстве» (A1, верификация FPS) — выполняет **пользователь вручную** на физическом Android. AI-агент его не делает.

### 0.3 Технологический контекст
- Flutter 3.x, Dart 3.x.
- State management: **Riverpod 2** (`flutter_riverpod`).
- Тестирование: `flutter_test` + `mockito`. Goldens — отсутствуют (создадим в этом плане).
- В UI-слое везде используется extension `context.palette` → `AppPalette` (см. `lib/core/constants/design_tokens.dart`).
- Темы: `AppPalette.light` и `AppPalette.dark` — два const-экземпляра. Любое добавление поля **обязательно** обновить в обоих.
- **Android рендерер:** Impeller включён по умолчанию (Flutter 3.27+). На старых GPU (Adreno 5xx, Mali-G52) Impeller рендерит `BackdropFilter` значительно дороже, чем Skia legacy. Это **может быть** корневым множителем стоимости — см. этап A0.
- **minSdk 24, targetSdk 36** (`android/app/build.gradle:10,24-25`). minSdk 24 = Android 7.0 — на таких устройствах blur особенно дорог.

### 0.4 Что НЕ трогать в этой ветке
- Business-логика (`features/transcription/*`, `features/settings/*`, `features/history/*`).
- Дизайн-токены `accent`, `accent2`, `good`, `bad`, `ink*`, `inkLine`, `shadow*`, `bgGradient`, `blobs` — менять **только** добавлением новых полей `glassBgFlat`/`glassBgFlatDeep`.
- Зависимости в `pubspec.yaml`.
- Существующие тесты (только дополнять, не править поведение).

---

## 1. Корневая причина просадок

`BackdropFilter(ImageFilter.blur(...))` в `GlassCard` (`lib/ui/widgets/glass_card.dart:33-34`) — самый дорогой rasterization-step. Цена: O(площадь × sigma²) **за каждый кадр прокрутки и за каждый видимый экземпляр**. `RepaintBoundary` его не спасает: backdrop по определению читает пиксели «снизу» и обязан пересчитываться при движении контента под ним.

**Хот-зоны** (прокручиваемые списки из `GlassCard`):

| Экран | Где | Количество blur-карточек |
|---|---|---|
| HistoryScreen | `_HistoryList` → каждый `_HistoryTile = GlassCard` | по числу записей в скролле |
| SettingsScreen | каждый `_Group = GlassCard` | 6+ групп |
| ApiKeysScreen | `_buildKeysList` → каждый ключ в `GlassCard` | N ключей |
| ProcessingScreen | `ChunkedProgressSection.ListView` → `ChunkTile` (это не GlassCard, но имитирует) | M чанков |

Дополнительные blur'ы (не в скролле, но влияют):

| Локация | sigma | Когда виден |
|---|---|---|
| `liquid_glass_tab_bar.dart:38` | 28 | **всегда** на экране |
| `no_keys_dialog.dart:51` | 34 | модалка |
| `settings_screen.dart:446` (bottom-sheet) | 34 | при открытии sheet |
| `api_keys_screen.dart:106` (confirm dialog) | 34 | при открытии диалога |

---

## 2. Метрика успеха

### 2.1 Объективная (делает **пользователь** на физическом Android)
```bash
/opt/flutter/bin/flutter run --profile -d <device-id>
```
В коде временно включается `showPerformanceOverlay: true` (см. §6.A1).

**Целевые числа:**
- HistoryScreen с ≥20 записями, flick-scroll: средний кадр **< 8 ms**, отсутствие missed frames на raster thread.
- SettingsScreen scroll: средний кадр **< 6 ms**.
- Открытие BottomSheet / NoKeysDialog: первый кадр **< 16 ms**.

### 2.2 Регрессионная (делает **агент**)
1. `flutter analyze` — 0 warnings (через ctx_execute, не Bash).
2. `flutter test` — все тесты зелёные.
3. Golden-тесты для трёх скролл-экранов (создадим в A1) — совпадают с эталоном после каждого фикса.

---

## 3. Стратегия визуальной идентичности

### 3.1 Принцип
Удаление blur меняет видимый цвет карточки: blur размывает контрастный фон под карточкой → итоговый цвет «насыщеннее» исходного `glassBg`. Если просто убрать blur — карточка станет светлее/прозрачнее эталона.

**Компенсация:** вводим **два новых токена** в `AppPalette`:

```dart
final Color glassBgFlat;     // для GlassCard(flat: true) без deep
final Color glassBgFlatDeep; // для GlassCard(flat: true, deep: true)
```

Стартовые значения (выверить через golden-тесты):

| Тема | glassBg → glassBgFlat | glassBgDeep → glassBgFlatDeep |
|---|---|---|
| Light | `0x7AFFFFFF` (.48) → **`0x99FFFFFF` (.60)** | `0xA8FFFFFF` (.66) → **`0xC2FFFFFF` (.76)** |
| Dark | `0x0FFFFFFF` (.06) → **`0x1FFFFFFF` (.12)** | `0x1AFFFFFF` (.10) → **`0x33FFFFFF` (.20)** |

> Эти значения — **стартовая точка**, не финальная. Алгоритм калибровки: см. §4.

### 3.2 Алгоритм калибровки (что делать когда golden-diff красный)
1. После применения фикса, который меняет визуал → запускается golden-тест.
2. Если diff показывает: **flat-карточка светлее эталона** → поднять alpha на **+0.03** в обоих темах.
3. Если **темнее** → опустить alpha на **-0.03**.
4. Повторять пока pixel diff не уйдёт ниже порога (см. §3.4 — tolerance comparator, **не 0%**).
5. После сходимости — обновить golden (`flutter test --update-goldens`) на коммит до B-этапа (эталон!), затем гонять все B-коммиты против него.

> **ВАЖНО:** эталонные goldens делаются на коммите до B1 — то есть с ещё работающим blur. Иначе цель «не отличается визуально» теряет смысл.

### 3.3 Pixel-perfect недостижим — почему и что делаем

Под скролл-карточками лежит `GradientBackground` с **5 радиальными блобами** (`design_tokens.dart:73-78`). `BackdropFilter` размывает блобы под карточкой в усреднённый цвет, `flat` рисует **поверх острой границы блоба**. Никакая корректировка глобальной alpha не даст 0% pixel-diff: разница локальная, по углам карточек.

**Поэтому goldens прогоняются на двух раздельных сценах:**

| Сцена | Что под карточкой | Назначение |
|---|---|---|
| `flat_uniform` | `ColoredBox(palette.bgGradient.colors.first)` — однородный цвет | **Жёсткий gate**: tolerance 0.5%. Калибрует общую alpha. |
| `flat_realistic` | Полный `GradientBackground` с блобами | **Мягкий gate**: tolerance 5%. Ловит грубые регрессии, не критичен к локальным расхождениям. |

Алгоритм калибровки (шаг 2-4 в §3.2) применяется **только к `flat_uniform`**. `flat_realistic` — мониторинг, не блокирующий.

### 3.4 Tolerance comparator

В `test/golden/scroll_screens_golden_test.dart` использовать кастомный comparator:

```dart
import 'package:flutter_test/flutter_test.dart';

class TolerantGoldenComparator extends LocalFileComparator {
  TolerantGoldenComparator(super.testFile, this.toleranceFraction);
  final double toleranceFraction; // 0.005 = 0.5%, 0.05 = 5%

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed) return true;
    if (result.diffPercent <= toleranceFraction) return true;
    throw FlutterError(result.error);
  }
}
```

Подключается в `setUpAll` теста (per-scene tolerance — отдельные группы для uniform/realistic).

### 3.5 Когда оставляем blur
Hero-карточки (1 экземпляр на экране, не в скролле) — blur остаётся:
- `FileCard` в HomeScreen (выбранный файл).
- `_EmptyDropzone` в HomeScreen (пустое состояние).
- `_StatusCard` в SettingsScreen (Groq connection).
- `GlassTile` в ProcessingScreen.
- `GlassIconBtn` (мелкие иконочные кнопки) — у них микро-blur, и количество ≤ 3-4 на экран.
- Модалки и BottomSheets — там снижаем `sigma`, но blur оставляем (этап D).

**Исключение: disabled `GlassIconBtn`** — переходит на `flat: true` (см. §5.8), потому что прежний `Opacity(0.38)` тускнел всю стеклянную карточку, а простой alpha-цвет иконки не воспроизведёт этот эффект → визуальный регресс.

---

## 4. Тестовая инфраструктура

### 4.1 Существующие тесты (не ломать!)
```
test/
├── widget_test.dart                                  # базовый smoke
├── widget/
│   ├── home_screen_smoke_test.dart                   # ⚠ может зацепиться
│   ├── result_screen_test.dart                       # ⚠ может зацепиться
│   └── api_keys_screen_status_test.dart              # ⚠ может зацепиться
├── unit/                                             # business-logic — не трогаем
├── features/transcription/                           # business-logic — не трогаем
├── features/settings/                                # business-logic — не трогаем
└── core/services/                                    # business-logic — не трогаем
```

После каждого коммита — гонять `flutter test` целиком (через ctx_execute).

### 4.2 Golden-тесты (создаём)
Создать `test/golden/scroll_screens_golden_test.dart` с **двумя группами сцен** (см. §3.3):

**Группа A — `flat_uniform` (жёсткий gate, tolerance 0.5%)**, фон под виджетом = `ColoredBox`:
- `HistoryScreen_5entries_uniform_light`
- `HistoryScreen_5entries_uniform_dark`
- `SettingsScreen_group_uniform_light`
- `SettingsScreen_group_uniform_dark`
- `ApiKeysScreen_3keys_uniform_light`
- `ApiKeysScreen_3keys_uniform_dark`

**Группа B — `flat_realistic` (мягкий gate, tolerance 5%)**, фон = полный `GradientBackground`:
- те же шесть сцен, но `_realistic_*` суффикс.

Goldens хранятся в `test/golden/goldens/*.png`.

### 4.3 Стабильность goldens (хост-агностика)

Goldens рендерятся на хост-машине (Linux/WSL). Чтобы они не плыли при смене ОС/Flutter-версии:

1. **Шрифты:** в `setUpAll` теста загрузить шрифты явно, не полагаться на системные:
   ```dart
   setUpAll(() async {
     TestWidgetsFlutterBinding.ensureInitialized();
     // Грузим Roboto или встроенный в Flutter Ahem — главное, фиксированный набор.
     await loadAppFonts();
   });
   ```
   `loadAppFonts` берётся из пакета `golden_toolkit` либо пишется руками: рекурсивно читать `*.ttf/*.otf` из `pubspec.yaml` ассетов через `FontLoader`.
2. **Фиксированный `surfaceSize`:** `tester.binding.setSurfaceSize(const Size(390, 844))` — единый эталон, не зависит от теста.
3. **Зафиксировать `devicePixelRatio`:** `tester.view.devicePixelRatio = 1.0` перед `pumpWidget`.
4. **`useGoldenFileComparator`:** установить `TolerantGoldenComparator` (§3.4) в `setUp` — отдельный экземпляр для каждой группы (uniform 0.5% / realistic 5%).
5. **Запускать только на Linux/WSL** в CI (макет фронта мака даст сдвиг шрифтов). Платформа-маркер: `@Tags(['golden'])` + в `dart_test.yaml` указать `linux` only.

### 4.4 Эталон и регрессии
**Эталон фиксируется в коммите A1** (до изменений в UI, с ещё работающим blur).
**После каждого B-коммита** прогонять `flutter test test/golden/` и сверять. При diff — калибровать alpha (§3.2).

---

## 5. Готовый код (вставлять без изменений, кроме калибровки alpha)

### 5.1 Новые поля в `AppPalette` (`lib/core/constants/design_tokens.dart`)

**Шаг 1.** В конструкторе `AppPalette` добавить параметры:
```dart
class AppPalette {
  const AppPalette({
    required this.accent,
    required this.accent2,
    required this.good,
    required this.bad,
    required this.ink1,
    required this.ink2,
    required this.ink3,
    required this.inkLine,
    required this.glassBg,
    required this.glassBgDeep,
    required this.glassBgFlat,      // ← НОВОЕ
    required this.glassBgFlatDeep,  // ← НОВОЕ
    required this.glassRim,
    required this.bgGradient,
    required this.blobs,
    required this.shadow,
    required this.shadowDeep,
  });
  // ...
  final Color glassBg;
  final Color glassBgDeep;
  final Color glassBgFlat;       // ← НОВОЕ
  final Color glassBgFlatDeep;   // ← НОВОЕ
  final Color glassRim;
  // ...
}
```

**Шаг 2.** В `AppPalette.light` (после строки с `glassBgDeep:`):
```dart
    glassBg: Color(0x7AFFFFFF),       // .48
    glassBgDeep: Color(0xA8FFFFFF),   // .66
    glassBgFlat: Color(0x99FFFFFF),       // .60 — компенсация отсутствия blur
    glassBgFlatDeep: Color(0xC2FFFFFF),   // .76
    glassRim: Color(0xD9FFFFFF),
```

**Шаг 3.** В `AppPalette.dark`:
```dart
    glassBg: Color(0x0FFFFFFF),       // .06
    glassBgDeep: Color(0x1AFFFFFF),   // .10
    glassBgFlat: Color(0x1FFFFFFF),       // .12 — компенсация отсутствия blur
    glassBgFlatDeep: Color(0x33FFFFFF),   // .20
    glassRim: Color(0x24FFFFFF),      // .14
```

### 5.2 Полный `GlassCard` после фикса (`lib/ui/widgets/glass_card.dart`)

Заменить файл **целиком** на:

```dart
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/constants/design_tokens.dart';

/// Glass-карточка с BackdropFilter и rim-границами.
/// Цвета берёт из `context.palette` — корректно в обеих темах.
///
/// `flat: true` — отключает дорогой BackdropFilter и использует
/// компенсирующий цвет [AppPalette.glassBgFlat] / [glassBgFlatDeep].
/// Используется в скролл-списках, где blur умножается на N карточек.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = AppRadius.card,
    this.padding = const EdgeInsets.all(16),
    this.deep = false,
    this.flat = false,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsets padding;

  /// Глубже стекло (выше насыщенность) — для модалок и status-карточек.
  final bool deep;

  /// Без BackdropFilter (для скролл-списков). Компенсируется повышенной alpha.
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    if (flat) {
      // Без blur: одна аллокация Container'а на кадр, без BackdropFilter.
      return RepaintBoundary(
        child: Container(
          decoration: BoxDecoration(
            color: deep ? palette.glassBgFlatDeep : palette.glassBgFlat,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: palette.glassRim, width: 0.5),
            boxShadow: [deep ? palette.shadowDeep : palette.shadow],
          ),
          padding: padding,
          child: child,
        ),
      );
    }

    final bg = deep ? palette.glassBgDeep : palette.glassBg;
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: deep ? 14 : 10, sigmaY: deep ? 14 : 10),
          child: Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: palette.glassRim, width: 0.5),
              boxShadow: [deep ? palette.shadowDeep : palette.shadow],
            ),
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}
```

### 5.3 Performance Overlay в `lib/ui/app.dart`

В `MaterialApp(...)` (line ~22) добавить параметр **временно** (только для A1-замера, удалить в финальном коммите):

```dart
return MaterialApp(
  title: 'ezctx',
  debugShowCheckedModeBanner: false,
  showPerformanceOverlay: true,   // ← ВРЕМЕННО для замеров
  themeMode: themeMode,
  // ...
);
```

Финальный коммит плана — удаление этой строки (этап F).

### 5.4 Точечные правки в скрин-файлах

**`lib/ui/screens/history_screen.dart:80`** — в `_HistoryTile.build`:
```dart
return GlassCard(
  flat: true,                  // ← ДОБАВИТЬ
  borderRadius: 22,
  padding: const EdgeInsets.all(14),
  child: Row(/* ... */),
);
```

**`lib/ui/screens/settings_screen.dart`** — в классе `_Group` (line 243, искать по сигнатуре `class _Group extends StatelessWidget`):
```dart
return Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: GlassCard(
    flat: true,                // ← ДОБАВИТЬ
    borderRadius: 22,
    padding: EdgeInsets.zero,
    child: Column(children: children),
  ),
);
```

**`lib/ui/screens/api_keys_screen.dart`** — в `_buildKeysList` внутри `key`-iteration:
```dart
return Padding(
  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
  child: RepaintBoundary(             // ← обернуть (Column не даёт авто-boundary)
    child: GlassCard(
      flat: true,                     // ← ДОБАВИТЬ
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(/* ... */),
    ),
  ),
);
```

**`lib/ui/widgets/chunk_tile.dart`** — заменить `palette.glassBg` на `palette.glassBgFlat`:
```dart
return Container(
  margin: const EdgeInsets.only(bottom: AppSpacing.xs),
  padding: const EdgeInsets.symmetric(
    horizontal: AppSpacing.md,
    vertical: AppSpacing.sm,
  ),
  decoration: BoxDecoration(
    color: palette.glassBgFlat,        // ← БЫЛО palette.glassBg
    borderRadius: BorderRadius.circular(/* ... */),
    // ...
  ),
);
```
> Причина: ChunkTile живёт рядом с flat-карточками. Если оставить `glassBg`, он будет визуально «бледнее» соседей.

### 5.5 RepaintBoundary вокруг WallpaperPainter (`lib/ui/widgets/gradient_background.dart`)

Заменить тело `build`:
```dart
@override
Widget build(BuildContext context) {
  final palette = context.palette;

  return RepaintBoundary(
    child: Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: DecoratedBox(decoration: BoxDecoration(gradient: palette.bgGradient)),
        ),
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(painter: _WallpaperPainter(palette)),
          ),
        ),
        child,
      ],
    ),
  );
}
```

### 5.6 TabBar sigma 28 → 12 (`lib/ui/widgets/liquid_glass_tab_bar.dart:38`)
```dart
filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),  // было 28, 28
```

### 5.7 Модалки sigma 34 → 14
- `lib/ui/widgets/no_keys_dialog.dart:51` → `sigmaX: 14, sigmaY: 14`
- `lib/ui/screens/settings_screen.dart:446` → `sigmaX: 14, sigmaY: 14`
- `lib/ui/screens/api_keys_screen.dart:106` → `sigmaX: 14, sigmaY: 14`

### 5.8 GlassIconBtn (`lib/ui/widgets/glass_icon_btn.dart`)
Заменить тело `build`:
```dart
@override
Widget build(BuildContext context) {
  final isDisabled = onPressed == null;
  final iconColor = Theme.of(context).colorScheme.onSurface
      .withValues(alpha: isDisabled ? 0.38 : 1.0);

  return Semantics(
    label: semanticLabel,
    button: true,
    child: SizedBox(
      width: 44,
      height: 44,
      child: GestureDetector(
        onTap: onPressed,
        child: Center(
          // Disabled → flat (без blur), чтобы стеклянный фон тоже «потускнел».
          // Active → обычный GlassCard с blur (1 экземпляр на экране — цена приемлема).
          child: GlassCard(
            flat: isDisabled,
            borderRadius: 14,
            padding: EdgeInsets.zero,
            child: SizedBox(
              width: 36,
              height: 36,
              child: Center(
                child: Icon(icon, size: iconSize, color: iconColor),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
```
> Убрали `Opacity` (форсирует saveLayer на каждый кадр).
> Альфа применяется к **цвету иконки** + для disabled — карточка переходит на `flat: true` (имитирует прежнее «всё потускнело»).
> Goldens сценарий disabled-кнопки добавить отдельным виджет-тестом (часть A1).

### 5.9 WaveformPainter (`lib/ui/widgets/file_card.dart`)
В `_WaveformPainter.paint`, заменить per-bar shader на один Paint:
```dart
@override
void paint(Canvas canvas, Size size) {
  const bars = 48;
  final w = size.width / bars;
  final barW = w * 0.55;
  final gap = w - barW;

  // Один shader на всю панель — вертикальный градиент сверху-вниз.
  final panelPaint = Paint()
    ..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [accent2.withValues(alpha: 0.85), accent.withValues(alpha: 0.55)],
    ).createShader(Offset.zero & size);

  for (var i = 0; i < bars; i++) {
    final v = (math.sin(i * 1.7) * math.cos(i * 0.6 + 1.1))
        .abs()
        .clamp(0.16, 1.0);
    final h = v * size.height;
    final x = i * w + gap / 2;
    final y = (size.height - h) / 2;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, barW, h),
      const Radius.circular(2),
    );
    canvas.drawRRect(rect, panelPaint);
  }
}
```
И обернуть `CustomPaint` в FileCard (`file_card.dart:128-135` ориентировочно) в `RepaintBoundary`:
```dart
child: RepaintBoundary(
  child: CustomPaint(
    painter: _WaveformPainter(
      accent: palette.accent,
      accent2: palette.accent2,
    ),
    size: Size.infinite,
  ),
),
```

### 5.10 ShimmerBar (`lib/ui/widgets/shimmer_bar.dart`)
Вынести `MediaQuery.sizeOf` из `AnimatedBuilder`:
```dart
@override
Widget build(BuildContext context) {
  final palette = context.palette;
  final screenWidth = MediaQuery.sizeOf(context).width;  // ← один раз
  return AnimatedBuilder(
    animation: _animation,
    builder: (_, __) {
      return ClipRRect(
        // ...
        FractionallySizedBox(
          widthFactor: 0.35,
          child: Transform.translate(
            offset: Offset(
              (_animation.value * 2 - 0.35) * screenWidth,  // ← без MediaQuery в builder
              0,
            ),
            // ...
```

### 5.13 Отложенный BackdropFilter для модалок (опционально, этап D3)

Подтверждено: `no_keys_dialog.dart:33-35` и `api_keys_screen.dart:92` оборачивают blur-карточку в `FadeTransition` + `ScaleTransition`. Это **`saveLayer` поверх `BackdropFilter`** на ~13 кадров входной анимации — основной источник missed-frame'ов первого кадра.

Снижение sigma (D2) уменьшает стоимость каждого кадра, **но не отменяет проблему**. Если после D2 на устройстве пользователя первый кадр модалки всё ещё > 16 ms — применить **D3**: показать flat-вариант на входной анимации, заменить на blur после её завершения.

Шаблон для `no_keys_dialog.dart` (и аналогично для `api_keys_screen` confirm-dialog):

```dart
@override
Widget build(BuildContext context) {
  final palette = context.palette;
  // ModalRoute.animation — анимация открытия (из showGeneralDialog).
  final route = ModalRoute.of(context);
  return Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: AnimatedBuilder(
        animation: route?.animation ?? const AlwaysStoppedAnimation(1.0),
        builder: (context, child) {
          final completed = (route?.animation?.status == AnimationStatus.completed);
          if (!completed) {
            // На входной анимации — flat (без BackdropFilter).
            return Container(
              constraints: const BoxConstraints(maxWidth: 360),
              decoration: BoxDecoration(
                color: palette.glassBgFlatDeep,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: palette.glassRim, width: 0.5),
                boxShadow: [palette.shadowDeep],
              ),
              child: child,
            );
          }
          // По завершении — настоящий blur.
          return ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 360),
                decoration: BoxDecoration(
                  color: palette.glassBgDeep,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: palette.glassRim, width: 0.5),
                ),
                child: child,
              ),
            ),
          );
        },
        child: /* содержимое диалога */,
      ),
    ),
  );
}
```

> **D3 — НЕ обязательный.** Применяется только если после D2 первый кадр модалки на mid-range Android всё ещё > 16 ms (по замеру пользователя). При применении — снять отдельный коммит, проверить goldens (статичная картинка модалки = состояние `completed`, не должна отличаться).

### 5.11 ChunkedProgressSection: ListView → Column (`lib/ui/widgets/chunked_progress_section.dart`)
Заменить блок `ListView.builder` в `ChunkedProcessing` ветке:
```dart
ExpansionTile(
  title: Text('Детали чанков', style: AppTextStyles.label.copyWith(color: palette.ink2)),
  initiallyExpanded: true,
  tilePadding: EdgeInsets.zero,
  childrenPadding: EdgeInsets.zero,
  children: [
    Column(
      children: [
        for (final c in chunks) ChunkTile(state: c),
      ],
    ),
  ],
),
```

### 5.14 Low-end fallback (опционально, этап G)

Подтверждено: `minSdk 24` (`android/app/build.gradle:24`) допускает устройства с Adreno 5xx / Mali-G52. Если после полного применения плана пользователь на таком устройстве сообщает «всё ещё дёргается» — включить **глобальный flat-режим** для всех GlassCard (включая hero-карточки).

Один источник правды — `LowEndMode` в `app.dart`:

```dart
// lib/ui/widgets/low_end_mode.dart (новый файл)
import 'package:flutter/material.dart';

class LowEndMode extends InheritedWidget {
  const LowEndMode({super.key, required this.forceFlat, required super.child});
  final bool forceFlat;

  static bool of(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<LowEndMode>();
    return w?.forceFlat ?? false;
  }

  @override
  bool updateShouldNotify(LowEndMode oldWidget) => forceFlat != oldWidget.forceFlat;
}
```

В `app.dart` обернуть `home`:
```dart
home: LowEndMode(
  forceFlat: MediaQuery.disableAnimationsOf(context),
  child: const ScaffoldWithNavBar(),
),
```

В `GlassCard.build`:
```dart
final effectiveFlat = flat || LowEndMode.of(context);
if (effectiveFlat) { /* ветка без BackdropFilter */ }
```

> **G — НЕ обязательный.** Включается только после фактической жалобы на low-end устройство. Сигнал `MediaQuery.disableAnimations` — стандартный Android accessibility-флаг «Remove animations». Альтернативно: завести `SharedPreferences` ключ `low_end_mode` и выставлять флаг из настроек.

---

## 6. Порядок коммитов (план выполнения)

Каждый коммит **атомарный**. Между коммитами — `flutter analyze` + `flutter test` (через `ctx_execute`) обязаны быть зелёными. Сообщения коммитов на русском, без авторства Claude.

| # | Коммит | Файлы | Этап |
|---|---|---|---|
| **A0** | **(не коммит) Пользовательский baseline-замер с/без Impeller** | — | **A0** |
| 0 | `chore(perf): scaffolding под golden-тесты скролл-экранов` | `test/golden/scroll_screens_golden_test.dart` (новый, создаёт эталоны) | A1 |
| 1 | `perf(ui): добавить токены glassBgFlat/glassBgFlatDeep в AppPalette` | `lib/core/constants/design_tokens.dart` | A2 |
| 2 | `perf(ui): GlassCard.flat — режим без BackdropFilter` | `lib/ui/widgets/glass_card.dart` | B1 |
| 3 | `perf(ui): HistoryScreen tiles в flat-режиме` | `lib/ui/screens/history_screen.dart` | B2 |
| 4 | `perf(ui): SettingsScreen группы в flat-режиме` | `lib/ui/screens/settings_screen.dart` (только `_Group`) | B3 |
| 5 | `perf(ui): ApiKeys ключи в flat-режиме + RepaintBoundary` | `lib/ui/screens/api_keys_screen.dart` | B4 |
| 6 | `perf(ui): ChunkTile на glassBgFlat — синхронизация с соседями` | `lib/ui/widgets/chunk_tile.dart` | B5 |
| 7 | `perf(ui): RepaintBoundary вокруг _WallpaperPainter` | `lib/ui/widgets/gradient_background.dart` | C1 |
| 8 | `perf(ui): LiquidGlassTabBar sigma 28 → 12` | `lib/ui/widgets/liquid_glass_tab_bar.dart` | D1 |
| 9 | `perf(ui): модалки blur 34 → 14` | `no_keys_dialog.dart`, `settings_screen.dart:446`, `api_keys_screen.dart:106` | D2 |
| 10 | `perf(ui): GlassIconBtn — Opacity → alpha цвета иконки` | `lib/ui/widgets/glass_icon_btn.dart` | E1 |
| 11 | `perf(ui): WaveformPainter — один shader + RepaintBoundary` | `lib/ui/widgets/file_card.dart` | E2 |
| 12 | `perf(ui): ShimmerBar — MediaQuery вне AnimatedBuilder` | `lib/ui/widgets/shimmer_bar.dart` | E3 |
| 13 | `perf(ui): ChunkedProgressSection ListView → Column` | `lib/ui/widgets/chunked_progress_section.dart` | E4 |
| **D3** | (опционально, по сигналу пользователя) `perf(ui): отложенный BackdropFilter в модалках до конца входной анимации` | `no_keys_dialog.dart`, `api_keys_screen.dart` (confirm) | D3 |
| **G** | (опционально) `perf(ui): low-end fallback — глобальный flat-режим` | новый `low_end_mode.dart`, `app.dart`, `glass_card.dart` | G |

> Performance Overlay (`showPerformanceOverlay: true` в `app.dart`) добавляется временно для замера пользователем — **не коммитится**. Возвращается в `false` перед merge.

### 6.0 Этап A0 — Impeller baseline (делает пользователь)

**До любых изменений в коде:**
1. Пользователь запускает на физическом Android-устройстве **два замера** одного и того же экрана (HistoryScreen с ≥20 записями, flick-scroll, Performance Overlay включён вручную):
   ```bash
   # Замер 1 — Impeller (дефолт):
   /opt/flutter/bin/flutter run --profile -d <device>

   # Замер 2 — Skia (legacy renderer):
   /opt/flutter/bin/flutter run --profile -d <device> --no-enable-impeller
   ```
2. Записывает средний кадр / max-кадр для каждого замера.
3. Сообщает агенту результаты.

**Интерпретация:**
- Skia в 2× и более быстрее → корневая причина в Impeller, а не в архитектуре UI. План всё равно делаем (он улучшит и Skia, и Impeller), но **не ждём чуда** — потолок Impeller ниже.
- Разница незначительная (< 20%) → корень в количестве blur'ов, план полностью применим.

> Этот шаг **не блокирует** A1. Если пользователь не может сделать замер сейчас — продолжаем с golden-инфры, замер делается параллельно.

### 6.1 Этап A1 в деталях
Перед всеми изменениями UI:

1. Создать `test/golden/scroll_screens_golden_test.dart` с тестами для HistoryScreen / SettingsScreen / ApiKeysScreen в light + dark темах.
2. Сгенерировать эталонные goldens:
   ```
   ctx_execute(language: "shell", code: "/opt/flutter/bin/flutter test --update-goldens test/golden/")
   ```
3. Закоммитить goldens — это **эталон ДО изменений**.

Дальнейшие коммиты (#1-#13) проверяются прогоном `flutter test test/golden/` против этого эталона. При расхождении — корректировать alpha в `design_tokens.dart` (§3.2), пока не сойдётся.

### 6.2 Этап F — финиш
Перед PR/merge:
- Удостовериться, что `showPerformanceOverlay` отсутствует в коммитах (либо удалить в дополнительном коммите).
- Обновить `README.md` если изменилось поведение (тут не должно — только perf).

---

## 7. Чек-лист валидации (на каждый коммит)

```
[ ] Применил изменения по §5
[ ] ctx_execute: /opt/flutter/bin/flutter analyze         → 0 warnings
[ ] ctx_execute: /opt/flutter/bin/flutter test            → все зелёные
[ ] ctx_execute: /opt/flutter/bin/flutter test test/golden/  → совпадает с эталоном
[ ] Если golden-diff: откалибровать alpha по §3.2, повторить
[ ] git add <конкретные файлы>  (не `-A`)
[ ] git commit с сообщением из §6 (русский, без Claude-авторства)
```

---

## 8. Откат

Каждый коммит атомарный. Если что-то идёт не так:
```
git revert <hash>
```
Без cascade-эффектов: каждый коммит не зависит от следующих, только от предыдущих в плане. Если развалился (например) коммит #11 — фиксим/откатываем только его.

---

## 9. Что делает пользователь (вне агента)

1. Подключить физическое Android-устройство к WSL (отдельная история с adb-over-network).
2. **A0 — Impeller baseline (см. §6.0)**: два замера одного экрана с Impeller и `--no-enable-impeller`. Сообщить агенту разницу.
3. До применения фиксов: записать средний кадр на HistoryScreen / SettingsScreen / ApiKeysScreen (через Performance Overlay).
4. После применения всех фиксов: повторить замер.
5. Сообщить агенту:
   - «всё ок, можно ship» → агент чистит overlay-флаг и готовит PR.
   - «модалки тормозят первый кадр» → агент применяет **D3** (§5.13).
   - «на устройстве X экран Y всё ещё тормозит при скролле» → агент применяет **G** (§5.14, low-end fallback).
6. Если ничего из вышеперечисленного не помогает — переход к расширенному дебагу (вне рамок этого плана).

---

## 10. Список заведённых тасков (контекст для новой сессии)

Если у тебя свежий чат — начинай с создания TaskCreate тасков:

**Обязательная цепочка:**
1. `Этап A0 — запросить у пользователя Impeller baseline (не блокирует, но получить до E)`
2. `Этап A1 — создать golden-тесты (uniform + realistic группы), TolerantGoldenComparator, loadAppFonts` (blocks 3)
3. `Этап A2 — добавить glassBgFlat/Deep в AppPalette (light + dark)` (blocks 4)
4. `Этап B1 — GlassCard.flat` (blocks 5-8)
5. `Этап B2 — HistoryScreen tiles flat`
6. `Этап B3 — SettingsScreen _Group flat`
7. `Этап B4 — ApiKeysScreen ключи flat + RepaintBoundary`
8. `Этап B5 — ChunkTile на glassBgFlat`
9. `Этап C1 — RepaintBoundary _WallpaperPainter`
10. `Этап D1 — TabBar sigma 12`
11. `Этап D2 — модалки sigma 14`
12. `Этап E1 — GlassIconBtn: Opacity → alpha + flat для disabled`
13. `Этап E2 — WaveformPainter один shader (с пометкой о визуальной регрессии)`
14. `Этап E3 — ShimmerBar MediaQuery вне AnimatedBuilder`
15. `Этап E4 — ChunkedProgressSection ListView → Column`
16. `Этап F — удалить showPerformanceOverlay из app.dart, PR-ready`

**Условные таски (только по сигналу пользователя):**
17. `Этап D3 — отложенный BackdropFilter для модалок (если первый кадр > 16ms)`
18. `Этап G — LowEndMode InheritedWidget, force-flat (если low-end устройство всё ещё тормозит)`

Обязательные таски — claim сразу. Условные — создавать **только после** обратной связи пользователя на E2/E3 этапе.

---

## 11. Открытые вопросы / решения по ходу

- Если goldens расходятся даже после калибровки alpha — возможно, нужно ещё поднять `glassRim` alpha (rim становится менее заметным без blur-фокуса). Стартовая правка: rim alpha +0.02 в dark.
- Если пользователь на устройстве сообщит, что TabBar sigma=12 заметно отличается от 28 — поднять до 16 (это всё ещё в 4-5 раз дешевле).
- Если кто-то жалуется, что dark-flat карточки «слишком прозрачные» — поднять `glassBgFlat` dark с .12 до .15.
