import 'package:flutter/material.dart';

import '../../core/constants/design_tokens.dart';

enum PipelineStatus { done, active, error, pending }

/// Строка шага pipeline с анимированной точкой статуса.
class PipelineStepTile extends StatelessWidget {
  const PipelineStepTile({
    super.key,
    required this.label,
    required this.status,
    required this.pulseController,
    required this.scaleAnimation,
    required this.opacityAnimation,
    this.inlineContent,
  });

  final String label;
  final PipelineStatus status;
  final AnimationController pulseController;
  final Animation<double> scaleAnimation;
  final Animation<double> opacityAnimation;

  /// Необязательный виджет под строкой шага (для chunked inline).
  final Widget? inlineContent;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final Color dotColor;
    final IconData? icon;

    switch (status) {
      case PipelineStatus.done:
        dotColor = palette.good;
        icon = Icons.check;
      case PipelineStatus.active:
        dotColor = palette.accent;
        icon = null;
      case PipelineStatus.error:
        dotColor = palette.bad;
        icon = Icons.error_outline;
      case PipelineStatus.pending:
        dotColor = palette.ink3;
        icon = null;
    }

    final dotWidget = Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: dotColor,
        shape: BoxShape.circle,
      ),
      child: icon != null ? Icon(icon, color: Colors.white, size: 14) : null,
    );

    final stepRow = Row(
      children: [
        if (status == PipelineStatus.active)
          AnimatedBuilder(
            animation: pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: scaleAnimation.value,
                child: Opacity(
                  opacity: opacityAnimation.value,
                  child: child,
                ),
              );
            },
            child: dotWidget,
          )
        else
          dotWidget,
        const SizedBox(width: AppSpacing.md),
        Text(label, style: AppTextStyles.body.copyWith(color: palette.ink1)),
      ],
    );

    if (inlineContent != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          stepRow,
          inlineContent!,
        ],
      );
    }

    return stepRow;
  }
}
