import 'package:flutter/material.dart';

import '../../core/constants/design_tokens.dart';
import 'glass_card.dart';

/// Hero-тайл с большим радиусом скругления (r-tile = 30px).
/// Используется для upload card, api-keys card и т.п.
class GlassTile extends StatelessWidget {
  const GlassTile({
    super.key,
    required this.child,
    this.borderRadius = AppRadius.tile,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: borderRadius,
      padding: padding,
      child: child,
    );
  }
}
