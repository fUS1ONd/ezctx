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

    return Semantics(
      label: semanticLabel,
      button: true,
      child: Opacity(
        opacity: isDisabled ? 0.38 : 1.0,
        child: SizedBox(
          width: 44,
          height: 44,
          child: GestureDetector(
            onTap: onPressed,
            child: Center(
              child: GlassCard(
                borderRadius: 14,
                padding: EdgeInsets.zero,
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(
                    child: Icon(
                      icon,
                      size: iconSize,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
