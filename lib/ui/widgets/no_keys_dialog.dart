import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/constants/design_tokens.dart';
import 'primary_button.dart';

/// Полноэкранная liquid-модалка «Нужен ключ Groq».
/// Появляется, когда пользователь нажимает «Транскрибировать» без API-ключа.
///
/// Usage:
/// ```dart
/// final ok = await NoKeysDialog.show(context);
/// if (ok == true) ScaffoldWithNavBar.of(context)?.switchTab(2);
/// ```
class NoKeysDialog extends StatelessWidget {
  const NoKeysDialog({super.key});

  /// Открывает диалог; возвращает `true`, если пользователь нажал
  /// «Открыть настройки», `null`/`false` — если закрыл.
  static Future<bool?> show(BuildContext context) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Закрыть',
      barrierColor: Colors.black.withValues(alpha: 0.42),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => const NoKeysDialog(),
      transitionBuilder: (context, anim, _, child) {
        final scale = Tween<double>(begin: 0.94, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutCubic))
            .animate(anim);
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(scale: scale, child: child),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 360),
              decoration: BoxDecoration(
                color: palette.glassBgDeep,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: palette.glassRim, width: 0.5),
                boxShadow: [palette.shadowDeep],
              ),
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [palette.accent2, palette.accent],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: palette.accent.withValues(alpha: 0.40),
                          blurRadius: 22,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.key_off_outlined,
                        color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Нужен ключ Groq',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.heading.copyWith(color: palette.ink1),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Чтобы запустить распознавание, добавьте API-ключ. '
                    'На free-tier Groq хватает на обычную лекцию.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body.copyWith(
                      color: palette.ink2,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 22),
                  PrimaryButton(
                    label: 'Открыть настройки',
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      foregroundColor: palette.ink2,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Не сейчас'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
