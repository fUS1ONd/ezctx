import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/constants/design_tokens.dart';
import '../../features/history/history_entry.dart';

/// Bottom sheet с действиями над записью — открывается по long-press карточки (D-06).
/// Glassmorphism-контейнер по паттерну _FiltersSheet из history_screen.dart.
class LongPressBottomSheet extends StatelessWidget {
  const LongPressBottomSheet({
    super.key,
    required this.entry,
    required this.onFavoriteToggle,
    required this.onCopy,
    required this.onShare,
    required this.onDelete,
  });

  /// Запись, для которой показывается sheet — нужна для лейбла избранного.
  final HistoryEntry entry;

  /// Колбэк тоггла избранного (ACT-02).
  final VoidCallback onFavoriteToggle;

  /// Колбэк копирования текста (ACT-03).
  final VoidCallback onCopy;

  /// Колбэк шаринга текста (ACT-03).
  final VoidCallback onShare;

  /// Колбэк удаления (ACT-04) — вызывается после закрытия sheet.
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: palette.glassBgDeep,
            border: Border(
              top: BorderSide(color: palette.glassRim, width: 0.5),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // DragHandle — визуальный индикатор для свайпа вниз.
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: palette.inkLine,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),

              // «В избранное» / «Убрать из избранного» — зависит от текущего состояния.
              _SheetTile(
                icon: entry.isFavorite ? Icons.star : Icons.star_border,
                label: entry.isFavorite ? 'Убрать из избранного' : 'В избранное',
                iconColor: entry.isFavorite ? palette.accent : palette.ink2,
                onTap: () {
                  Navigator.pop(context);
                  onFavoriteToggle();
                },
              ),

              // Копировать текст расшифровки (ACT-03).
              _SheetTile(
                icon: Icons.copy_all,
                label: 'Копировать',
                onTap: () {
                  Navigator.pop(context);
                  onCopy();
                },
              ),

              // Поделиться текстом расшифровки (ACT-03).
              _SheetTile(
                icon: Icons.share,
                label: 'Поделиться',
                onTap: () {
                  Navigator.pop(context);
                  onShare();
                },
              ),

              Divider(color: palette.inkLine, height: AppSpacing.sm),

              // Удалить запись — деструктивное действие (ACT-04).
              _SheetTile(
                icon: Icons.delete_outline,
                label: 'Удалить',
                iconColor: palette.bad,
                labelColor: palette.bad,
                onTap: () {
                  Navigator.pop(context);
                  onDelete();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Строка действия в bottom sheet: иконка + подпись.
class _SheetTile extends StatelessWidget {
  const _SheetTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.labelColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Цвет иконки — по умолчанию palette.ink2.
  final Color? iconColor;

  /// Цвет подписи — по умолчанию palette.ink1.
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ListTile(
      leading: Icon(
        icon,
        size: AppSpacing.lg,
        color: iconColor ?? palette.ink2,
      ),
      title: Text(
        label,
        style: AppTextStyles.body.copyWith(
          color: labelColor ?? palette.ink1,
        ),
      ),
      onTap: onTap,
    );
  }
}
