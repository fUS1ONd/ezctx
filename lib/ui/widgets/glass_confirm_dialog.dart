import 'package:flutter/material.dart';

import '../../core/constants/design_tokens.dart';
import 'glass_card.dart';

/// Стеклянный confirm-диалог — замена стандартного Material3-диалога (D-07).
/// Используется для подтверждения удаления записи/очистки истории.
///
/// Возвращает `true`, если пользователь нажал на confirm-кнопку,
/// `false` — если на cancel, `null` — если закрыл тапом по барьеру
/// (`barrierDismissible: true`).
///
/// [destructive] управляет цветом confirm-кнопки: `palette.bad` для
/// деструктивных действий (удаление), `palette.accent` — для остальных.
Future<bool?> showGlassConfirmDialog({
  required BuildContext context,
  required String title,
  required String body,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = true,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      final palette = ctx.palette;
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: GlassCard(
          deep: true,
          borderRadius: AppRadius.card,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.heading.copyWith(color: palette.ink1),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                body,
                style: AppTextStyles.body.copyWith(color: palette.ink2),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: TextButton.styleFrom(foregroundColor: palette.ink2),
                    child: Text(cancelLabel),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: TextButton.styleFrom(
                      foregroundColor:
                          destructive ? palette.bad : palette.accent,
                    ),
                    child: Text(confirmLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
