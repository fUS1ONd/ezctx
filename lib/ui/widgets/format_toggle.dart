import 'package:flutter/material.dart';

import '../../core/constants/design_tokens.dart';

/// Переключатель формата отображения расшифровки «Вид: [С метками][Без меток]».
/// Общий для экрана результата и detail-экрана Истории (D6).
class FormatToggle extends StatelessWidget {
  const FormatToggle({
    super.key,
    required this.showTimestamps,
    required this.onChanged,
  });

  /// true — выбран режим «С метками»; false — «Без меток».
  final bool showTimestamps;

  /// Вызывается с новым значением showTimestamps при тапе.
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Вид:',
          style: AppTextStyles.label.copyWith(color: context.palette.ink2),
        ),
        const SizedBox(width: AppSpacing.sm),
        // Используем ChoiceChip-пару для наглядного переключения.
        _FormatChip(
          label: 'С метками',
          selected: showTimestamps,
          onTap: () => onChanged(true),
        ),
        const SizedBox(width: AppSpacing.xs),
        _FormatChip(
          label: 'Без меток',
          selected: !showTimestamps,
          onTap: () => onChanged(false),
        ),
      ],
    );
  }
}

/// Минималистичный чип-переключатель для выбора формата отображения.
class _FormatChip extends StatelessWidget {
  const _FormatChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: selected
              ? palette.accent.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected
                ? palette.accent.withValues(alpha: 0.5)
                : palette.inkLine,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.label.copyWith(
            color: selected ? palette.accent : palette.ink2,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
