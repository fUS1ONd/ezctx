import 'package:flutter/material.dart';

import '../../core/constants/design_tokens.dart';
import '../widgets/gradient_background.dart';

/// Placeholder экрана истории транскрипций (реализация в следующей фазе).
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history_outlined,
                  size: 64,
                  color: AppColors.inkTertiary,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'История появится скоро',
                  style: AppTextStyles.heading.copyWith(
                    color: AppColors.inkSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
