import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/design_tokens.dart';
import '../widgets/glass_icon_btn.dart';
import '../widgets/glass_tile.dart';
import '../widgets/gradient_background.dart';

/// Главный экран (Empty State).
/// В Plan 01 — скелет без file picker (будет в Plan 03).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
                // Шапка: логотип + название + кнопка настроек
                Row(
                  children: [
                    // Иконка-логотип
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: AppGradients.accent,
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Слух', style: AppTextStyles.heading),
                    const Spacer(),
                    GlassIconBtn(
                      icon: Icons.settings_outlined,
                      semanticLabel: 'Настройки',
                      onPressed: () =>
                          Navigator.pushNamed(context, AppConstants.routeSettings),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                // Display заголовок
                const Text(
                  'Расшифруй\nлюбой звук',
                  style: AppTextStyles.display,
                ),
                const SizedBox(height: AppSpacing.md),
                // Subtitle
                Text(
                  'Загрузите аудиозапись лекции и получите готовый текст',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.inkSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                // Upload card (заглушка — file picker будет в Plan 03)
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Будет реализовано в следующем плане'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: GlassTile(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Upload иконка в accent-контейнере
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            gradient: AppGradients.accent,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: const Icon(
                            Icons.upload_outlined,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const Text('Выберите файл', style: AppTextStyles.heading),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'mp3, wav, m4a, ogg, flac · до 19 МБ',
                          style: AppTextStyles.label,
                          textAlign: TextAlign.center,
                        ),
                      ],
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
