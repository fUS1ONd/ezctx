import 'package:flutter/material.dart';

import 'glass_card.dart';

/// Стеклянная icon-кнопка 36×36px с touch target 44×44px.
/// Accessibility: всегда оборачивается в Semantics с явным label.
class GlassIconBtn extends StatelessWidget {
  const GlassIconBtn({
    super.key,
    required this.icon,
    required this.semanticLabel,
    this.onPressed,
    this.iconSize = 20.0,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null;
    // Alpha применяется к цвету иконки — убирает Opacity(saveLayer) на каждый кадр.
    final iconColor = Theme.of(context)
        .colorScheme
        .onSurface
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
            // Disabled → flat (без blur), чтобы стеклянный фон тоже потускнел.
            // Active → обычный GlassCard с blur (1 экземпляр на экран, цена приемлема).
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
}
