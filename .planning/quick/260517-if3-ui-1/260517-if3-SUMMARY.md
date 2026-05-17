---
phase: quick-260517-if3-ui-1
plan: 01
subsystem: ui
tags: [animation, glass-design, safe-area, routing]
key-files:
  modified:
    - lib/ui/screens/processing_screen.dart
    - lib/ui/screens/home_screen.dart
    - lib/ui/screens/settings_screen.dart
    - lib/ui/app.dart
    - lib/ui/widgets/primary_button.dart
decisions:
  - GlassCard с borderRadius=AppRadius.pill для floating cancel pill
  - _DashedBorderPainter через Path.computeMetrics() для корректного пунктира по скруглённому контуру
  - Groq status card показывается только когда _keyCount > 0 и загрузка завершена
metrics:
  completed: "2026-05-17"
  tasks_completed: 3
  files_changed: 5
---

# Phase quick-260517-if3 Plan 01: UI Bug Fixes Summary

**One-liner:** Pulse-dot анимация, glass pill cancel bar, dashed border upload card, Groq status card, fade routing — 10 UI-багов закрыты за 1 волну.

## Tasks Completed

| # | Task | Commit | Key changes |
|---|------|--------|-------------|
| 1 | Processing screen — pulseDot, pill bar, safe area, GlassTile | `acf9d03` | processing_screen.dart +80/-26 |
| 2 | Home upload card — dashed border, pill, minHeight | `2d91896` | home_screen.dart +95/-8 |
| 3 | Settings status card + fade transitions + primary_button token | `29b65c9` | 3 файла +88/-7 |

## Changes by File

### lib/ui/screens/processing_screen.dart (`acf9d03`)

- **SingleTickerProviderStateMixin** добавлен к `_ProcessingScreenState`
- **AnimationController** `_pulseController` (1200 мс, `repeat(reverse: true)`)
- `_scaleAnimation` Tween 1.0 → 1.25, `_opacityAnimation` Tween 0.6 → 1.0
- `_buildPipelineStep`: активная точка оборачивается в `AnimatedBuilder` + `Transform.scale` + `Opacity`
- `_buildBottomBar(Loading)`: `GlassCard(borderRadius: AppRadius.pill)` с Row [elapsed timer | cancel button]
- Bottom padding: `SizedBox(height: MediaQuery.of(context).padding.bottom + 32)`
- Карточка файла: `GlassTile` вместо `GlassCard`
- `dispose()`: добавлен `_pulseController.dispose()`

### lib/ui/screens/home_screen.dart (`2d91896`)

- **`_DashedBorderPainter`** (CustomPainter): `Path.computeMetrics()` по RRect r=26, stroke 1.5px, dash 6px, gap 4px, `accent.withValues(alpha: 0.55)`
- Upload icon обёрнут в `CustomPaint(painter: _DashedBorderPainter, child: SizedBox(88×88))`
- **Pill «Из файлов»**: `Container` accent 0.12 opacity + `BorderRadius.all(Radius.circular(AppRadius.pill))`
- Upload card: `ConstrainedBox(constraints: BoxConstraints(minHeight: 260))`

### lib/ui/screens/settings_screen.dart (`29b65c9`)

- Импорт `glass_tile.dart` добавлен
- **`_buildGroqStatusCard()`**: `GlassTile` с 48×48 icon container (accent gradient, r=AppRadius.icon), heading «Подключено к Groq», green dot 8×8 + «API ключ активен»
- Карточка показывается при `!_loading && _keyCount > 0`

### lib/ui/app.dart (`29b65c9`)

- `routes: {}` заменён на `onGenerateRoute` + `_routeBuilders` Map
- `PageRouteBuilder`: `transitionDuration: 300ms`, `FadeTransition(CurvedAnimation(easeInOut))`

### lib/ui/widgets/primary_button.dart (`29b65c9`)

- `SizedBox(width: 8)` → `SizedBox(width: AppSpacing.sm)` (токен вместо magic number)

## Manual Check Checklist

- [ ] Processing screen: активная точка пульсирует ~1.2s (scale + opacity)
- [ ] Processing screen: floating pill bar с таймером и кнопкой «Отменить»
- [ ] Processing screen: карточка файла имеет r=30 (GlassTile)
- [ ] Processing screen: нет налезания контента на системную панель навигации
- [ ] Home screen: пунктирная accent-рамка вокруг upload-иконки
- [ ] Home screen: pill «Из файлов» виден под форматами
- [ ] Home screen: upload card не схлопывается ниже 260px
- [ ] Settings screen: статус-карточка «Подключено к Groq» видна (при наличии ключа)
- [ ] Переходы между экранами: плавный fade ~300ms (не slide)
- [ ] Primary button с иконкой: отступ без визуальной регрессии

## Deviations from Plan

None — план выполнен в точности. Единственная адаптация: `_DashedBorderPainter` рисует по прямоугольному контуру (не круглому), что соответствует форме иконки-контейнера 72×72 с r=22.

## Self-Check

Files exist:
- `lib/ui/screens/processing_screen.dart` — modified
- `lib/ui/screens/home_screen.dart` — modified
- `lib/ui/screens/settings_screen.dart` — modified
- `lib/ui/app.dart` — modified
- `lib/ui/widgets/primary_button.dart` — modified

Commits:
- `acf9d03` — Task 1
- `2d91896` — Task 2
- `29b65c9` — Task 3

flutter analyze: **No issues found** (все 5 файлов)

## Self-Check: PASSED
