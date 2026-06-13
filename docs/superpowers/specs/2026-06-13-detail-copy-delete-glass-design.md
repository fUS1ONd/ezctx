# Баги #9 и #10: Убрать снекбар "Скопировано" + Glass-диалог подтверждения удаления

## Контекст

После введения glass-стиля нижнего бара (баг #8) остались два визуальных несоответствия на `DetailScreen`:
1. Успешное копирование показывает SnackBar "Скопировано" — лишний шум без пользы (действие очевидно).
2. Диалог подтверждения удаления (`AlertDialog`) везде в приложении выглядит как стандартный Material-компонент, выбивающийся из glass-стилистики.

---

## Баг #9 — Убрать SnackBar "Скопировано"

### Изменение

В `lib/ui/screens/detail_screen.dart`, метод `_onCopyTap()`:

- **Удалить** блок `ScaffoldMessenger.showSnackBar(SnackBar('Скопировано', ...))` (строки 88–94) — успешное копирование больше не требует уведомления.
- **Оставить** SnackBar об ошибке (`'Ошибка копирования: $e'`) — он сигнализирует о сбое, который пользователь иначе не заметит.

Снекбары об ошибках в других обработчиках (`_onShareTap`, `_onDeleteTap`, `_onTitleSaved`, `_onFavoriteTap`) — **не трогать**, они вне scope.

---

## Баг #10 — Glass-диалог подтверждения удаления

### Новый виджет `GlassConfirmDialog`

**Файл:** `lib/ui/widgets/glass_confirm_dialog.dart`

Статический виджет + фабричный метод `show()`, аналог `NoKeysDialog`.

```dart
static Future<bool> show(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  Color? confirmColor,   // дефолт: palette.bad
}) → Future<bool>       // true = подтверждено, false = отмена/закрыт
```

### Визуальная структура

```
barrierColor: Colors.black.withValues(alpha: 0.42)
transitionDuration: 220ms
transition: fade + scale (0.94 → 1.0, easeOutCubic)

ClipRRect(borderRadius: 32)
└── BackdropFilter(blur: 14, 14)
    └── Container(
          glassBgDeep, glassRim border (0.5), shadowDeep,
          maxWidth: 320, padding: fromLTRB(24, 28, 24, 8)
        )
        └── Column(mainAxisSize: min)
              ├── Text(title,  style: heading, ink1, center)
              ├── SizedBox(8)
              ├── Text(body,   style: body,    ink2, center)
              ├── SizedBox(16)
              ├── Divider(color: glassRim, height: 1)
              └── Row(
                    ├── Expanded → TextButton('Отмена',       ink2)   → pop(false)
                    ├── VerticalDivider(color: glassRim, width: 1)
                    └── Expanded → TextButton(confirmLabel, confirmColor) → pop(true)
                  )
```

`VerticalDivider` между кнопками — тонкий разделитель `palette.glassRim`, `width: 1`. Каждая кнопка занимает половину строки (`Expanded`), высота кнопочной строки `48`.

### Замены `AlertDialog` → `GlassConfirmDialog.show()`

| Файл | Метод/контекст | title | body | confirmLabel |
|---|---|---|---|---|
| `detail_screen.dart:116` | `_onDeleteTap` | 'Удалить запись?' | 'Это действие нельзя отменить.' | 'Удалить' |
| `history_screen.dart:117` | `_onClearHistory` | 'Очистить историю?' | 'Все записи будут удалены безвозвратно.' | 'Очистить' |
| `history_screen.dart:200` | `onDelete` в `_showLongPressSheet` | 'Удалить запись?' | 'Это действие нельзя отменить.' | 'Удалить' |

Во всех трёх случаях `confirmColor` не передаётся — используется дефолт `palette.bad`.

### Тип возвращаемого значения

Текущий `showDialog<bool>` возвращает `bool?` (null при тапе вне диалога или кнопке «назад»). `GlassConfirmDialog.show()` возвращает `Future<bool>` — `barrierDismissible: true`, но закрытие через barrier / back-gesture = `false`. Вызывающий код меняется с `if (confirmed != true)` на `if (!confirmed)`.

---

## Тестирование

### Баг #9
- `_onCopyTap()` успешная копия → SnackBar «Скопировано» **не** появляется.
- `_onCopyTap()` при ошибке `ClipboardService` → SnackBar с текстом ошибки **появляется**.

### Баг #10
- Нажатие «Удалить» на `DetailScreen` → появляется glass-диалог (с blur-фоном, без AlertDialog-хрома).
- Нажатие «Отмена» / тап вне диалога / back → диалог закрывается, удаление **не** происходит.
- Нажатие «Удалить» в диалоге → запись удаляется, экран закрывается.
- Аналогично для «Очистить историю» и удаления через long-press в `HistoryScreen`.
- `flutter analyze` — No issues found.
- Существующие тесты `detail_delete` и `swipe_delete` в `test/widget/detail_screen_test.dart` проходят без изменений.
  - Если тест вызывает `find.byType(AlertDialog)` — заменить на `find.byType(GlassConfirmDialog)`.

---

## Decisions & Rationale

- **Row-кнопки, не стопка** — в confirm-диалоге обе опции равноценны (отмена ≠ второстепенное действие), горизонтальный ряд с разделителем — стандартный паттерн для бинарного выбора.
- **Возврат `bool` (не `bool?`)** — упрощает вызывающий код; закрытие через баррьер семантически равно «Отмена».
- **Общий виджет, не inline** — три идентичных диалога → один переиспользуемый виджет, как `NoKeysDialog`. Inline-подход увеличивает дублирование без выгоды.
- **`barrierDismissible: true`** — соответствует `NoKeysDialog` и стандартному UX: пользователь может передумать тапом вне диалога.
- **Scope**: только диалоги подтверждения деструктивных действий. Остальные `SnackBar` (об ошибках) не трогаем — они функциональны и вне этой задачи.
