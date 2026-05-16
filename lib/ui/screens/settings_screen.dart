import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/design_tokens.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_icon_btn.dart';
import '../widgets/gradient_background.dart';

/// Экран настроек.
/// В Plan 01 — список из одной строки «API-ключи».
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
                // Шапка с кнопкой назад
                Row(
                  children: [
                    GlassIconBtn(
                      icon: Icons.arrow_back,
                      semanticLabel: 'Назад',
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const Text('Настройки', style: AppTextStyles.heading),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                const Text('Настройки', style: AppTextStyles.display),
                const SizedBox(height: AppSpacing.lg),
                // Список настроек
                GlassCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          Icons.key_outlined,
                          color: AppColors.inkPrimary,
                        ),
                        title: const Text(
                          'API-ключи',
                          style: AppTextStyles.body,
                        ),
                        subtitle: Text(
                          'Нет ключей', // Plan 02 заменит на актуальный count
                          style: AppTextStyles.label,
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: AppColors.inkTertiary,
                        ),
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppConstants.routeApiKeys,
                        ),
                      ),
                    ],
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
