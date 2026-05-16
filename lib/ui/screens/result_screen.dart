import 'package:flutter/material.dart';

import '../../core/constants/design_tokens.dart';
import '../widgets/glass_icon_btn.dart';
import '../widgets/gradient_background.dart';

/// Экран результата транскрибации.
/// В Plan 01 — заглушка; наполняется в Plan 05.
class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    GlassIconBtn(
                      icon: Icons.arrow_back,
                      semanticLabel: 'Назад',
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const Text('Результат', style: AppTextStyles.heading),
                  ],
                ),
                const Expanded(
                  child: Center(
                    child: Text(
                      'TBD — заполняется в Plan 05',
                      style: AppTextStyles.body,
                    ),
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
