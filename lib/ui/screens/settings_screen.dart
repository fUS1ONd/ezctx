import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/design_tokens.dart';
import '../../core/storage/secure_storage_service.dart';
import '../../features/settings/api_key_repository.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_icon_btn.dart';
import '../widgets/gradient_background.dart';

/// Экран настроек.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _keyCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final keys = await ApiKeyRepository(SecureStorageServiceImpl()).listKeys();
    if (mounted) {
      setState(() {
        _keyCount = keys.length;
        _loading = false;
      });
    }
  }

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
                          _loading
                              ? '...'
                              : (_keyCount == 0
                                    ? 'Нет ключей'
                                    : '$_keyCount активен'),
                          style: AppTextStyles.label,
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: AppColors.inkTertiary,
                        ),
                        onTap: () async {
                          await Navigator.pushNamed(
                            context,
                            AppConstants.routeApiKeys,
                          );
                          _load();
                        },
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
