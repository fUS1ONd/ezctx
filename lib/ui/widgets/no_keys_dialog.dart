import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/constants/design_tokens.dart';
import 'primary_button.dart';

/// Параметризованная liquid-модалка «Нужен ключ».
/// По умолчанию показывает Groq-вариант (обратная совместимость).
/// Для Deepgram передайте [title], [bodyText] и [onOpenSettings].
///
/// Usage (Groq, без параметров — обратная совместимость):
/// ```dart
/// final ok = await NoKeysDialog.show(context);
/// if (ok == true) ScaffoldWithNavBar.of(context)?.switchTab(2);
/// ```
///
/// Usage (Deepgram):
/// ```dart
/// await NoKeysDialog.show(
///   context,
///   title: 'Нужен ключ Deepgram',
///   bodyText: 'Nova-3 работает через Deepgram...',
///   onOpenSettings: () => Navigator.pushNamed(context, routeApiKeys),
/// );
/// ```
class NoKeysDialog extends StatelessWidget {
  /// Заголовок диалога. Дефолт: Groq-вариант.
  final String title;

  /// Текст-подсказка в теле диалога. Дефолт: Groq-вариант.
  final String bodyText;

  /// Дополнительный callback при нажатии «Открыть настройки».
  /// Вызывается ПОСЛЕ закрытия диалога (Navigator.pop(true)).
  /// Если null — поведение идентично предыдущей версии.
  final VoidCallback? onOpenSettings;

  const NoKeysDialog({
    super.key,
    this.title = 'Нужен ключ Groq',
    this.bodyText =
        'Чтобы запустить распознавание, добавьте API-ключ. '
        'На free-tier Groq хватает на обычную лекцию.',
    this.onOpenSettings,
  });

  /// Открывает диалог; возвращает `true`, если пользователь нажал
  /// «Открыть настройки», `null`/`false` — если закрыл.
  ///
  /// Параметры [title], [bodyText], [onOpenSettings] позволяют
  /// показывать провайдер-специфичный вариант (например, Deepgram).
  /// При вызове без параметров поведение идентично предыдущей версии (Groq-дефолты).
  static Future<bool?> show(
    BuildContext context, {
    String title = 'Нужен ключ Groq',
    String bodyText =
        'Чтобы запустить распознавание, добавьте API-ключ. '
        'На free-tier Groq хватает на обычную лекцию.',
    VoidCallback? onOpenSettings,
  }) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Закрыть',
      barrierColor: Colors.black.withValues(alpha: 0.42),
      transitionDuration: const Duration(milliseconds: 220),
      // Убираем const — конструктор теперь принимает параметры
      pageBuilder: (_, __, ___) => NoKeysDialog(
        title: title,
        bodyText: bodyText,
        onOpenSettings: onOpenSettings,
      ),
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
      // Material с прозрачным фоном даёт корректный DefaultTextStyle:
      // без него Text вне Scaffold рисуется жёлтым с двойным подчёркиванием.
      child: Material(
        type: MaterialType.transparency,
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
                    // Иконка общая для всех провайдеров (UI-SPEC §3)
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
                    // Заголовок из параметра (Groq или Deepgram)
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style:
                          AppTextStyles.heading.copyWith(color: palette.ink1),
                    ),
                    const SizedBox(height: 8),
                    // Текст-подсказка из параметра
                    Text(
                      bodyText,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body.copyWith(
                        color: palette.ink2,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 22),
                    PrimaryButton(
                      label: 'Открыть настройки',
                      onPressed: () {
                        // Закрываем диалог с результатом true, затем вызываем callback
                        Navigator.of(context).pop(true);
                        onOpenSettings?.call();
                      },
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
      ),
    );
  }
}
