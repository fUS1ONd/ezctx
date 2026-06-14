import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/constants/design_tokens.dart';

class GlassConfirmDialog extends StatelessWidget {
  final String title;
  final String body;
  final String confirmLabel;
  final Color? confirmColor;

  const GlassConfirmDialog({
    super.key,
    required this.title,
    required this.body,
    required this.confirmLabel,
    this.confirmColor,
  });

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String body,
    required String confirmLabel,
    Color? confirmColor,
  }) async {
    final result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Закрыть',
      barrierColor: Colors.black.withValues(alpha: 0.42),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => GlassConfirmDialog(
        title: title,
        body: body,
        confirmLabel: confirmLabel,
        confirmColor: confirmColor,
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
    return result ?? false;
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
                constraints: const BoxConstraints(maxWidth: 320),
                decoration: BoxDecoration(
                  color: palette.glassBgDeep,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: palette.glassRim, width: 0.5),
                  boxShadow: [palette.shadowDeep],
                ),
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style:
                          AppTextStyles.heading.copyWith(color: palette.ink1),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      body,
                      style: AppTextStyles.body.copyWith(color: palette.ink2),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Divider(color: palette.glassRim, height: 1),
                    SizedBox(
                      height: 48,
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(
                                'Отмена',
                                style: TextStyle(color: palette.ink2),
                              ),
                            ),
                          ),
                          VerticalDivider(color: palette.glassRim, width: 1),
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text(
                                confirmLabel,
                                style: TextStyle(
                                  color: confirmColor ?? palette.bad,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
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
