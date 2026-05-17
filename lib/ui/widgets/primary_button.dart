import 'package:flutter/material.dart';

import '../../core/constants/design_tokens.dart';

enum PrimaryButtonVariant { accent, good }

/// Accent gradient pill кнопка (CTA).
/// Поддерживает variant: accent (по умолчанию) и good (зелёный, для «Скопировано»).
/// Высота 52px, радиус по умолчанию 14px.
class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.borderRadius = 14.0,
    this.variant = PrimaryButtonVariant.accent,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double borderRadius;
  final PrimaryButtonVariant variant;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _isPressed = false;

  LinearGradient _activeGradient() {
    return switch (widget.variant) {
      PrimaryButtonVariant.accent => AppGradients.accent,
      PrimaryButtonVariant.good => const LinearGradient(
          colors: [Color(0xFF3FCB9A), AppColors.good],
        ),
    };
  }

  Color _shadowColor() {
    return switch (widget.variant) {
      PrimaryButtonVariant.accent => AppColors.accent,
      PrimaryButtonVariant.good => AppColors.good,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null;

    final gradient = isDisabled
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFB0B0B0), Color(0xFF888888)],
          )
        : _activeGradient();

    return GestureDetector(
      onTapDown: isDisabled ? null : (_) => setState(() => _isPressed = true),
      onTapUp: isDisabled
          ? null
          : (_) {
              setState(() => _isPressed = false);
              widget.onPressed?.call();
            },
      onTapCancel:
          isDisabled ? null : () => setState(() => _isPressed = false),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 100),
        opacity: isDisabled
            ? 0.38
            : _isPressed
                ? 0.88
                : 1.0,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: isDisabled
                ? null
                : [
                    BoxShadow(
                      color: _shadowColor().withValues(alpha: 0.32),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, color: Colors.white, size: 20),
                  // Отступ через токен вместо magic number
                  const SizedBox(width: AppSpacing.sm),
                ],
                Text(
                  widget.label,
                  style: AppTextStyles.heading.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
