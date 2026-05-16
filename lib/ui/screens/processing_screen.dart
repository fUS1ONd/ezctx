import 'package:flutter/material.dart';

import '../../core/constants/design_tokens.dart';
import '../widgets/glass_icon_btn.dart';
import '../widgets/gradient_background.dart';

/// Экран обработки файла.
/// В Plan 01 — заглушка; наполняется в Plan 04.
class ProcessingScreen extends StatelessWidget {
  const ProcessingScreen({super.key});

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
                      icon: Icons.close,
                      semanticLabel: 'Закрыть',
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const Text('Обработка', style: AppTextStyles.heading),
                  ],
                ),
                const Expanded(
                  child: Center(
                    child: Text(
                      'TBD — заполняется в Plan 04',
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
