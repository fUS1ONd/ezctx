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
          filter: ImageFilter.blur(
              sigmaX: deep ? 14 : 10, sigmaY: deep ? 14 : 10),
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
