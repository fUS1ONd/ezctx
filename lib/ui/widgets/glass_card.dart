import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/constants/design_tokens.dart';

/// Стеклянная карточка с BackdropFilter и ClipRRect.
/// RepaintBoundary обязателен для производительности (RESEARCH Pitfall 4).
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = AppRadius.card,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.glassSurface,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.85),
                  width: 0.5,
                ),
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 0.5,
                ),
                left: BorderSide(
                  color: Colors.white.withValues(alpha: 0.58),
                  width: 0.5,
                ),
                right: BorderSide(
                  color: Colors.white.withValues(alpha: 0.16),
                  width: 0.5,
                ),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A140A1E),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}
