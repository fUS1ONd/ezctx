import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/design_tokens.dart';
import '../../core/storage/secure_storage_service.dart';
import '../../features/settings/api_key_repository.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_icon_btn.dart';
import '../widgets/glass_tile.dart';
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

  /// Корректное русское склонение для количества активных ключей.
  String _keyCountLabel(int count) {
    if (count == 0) return 'Нет ключей';
    if (count == 1) return '1 активен';
    if (count <= 4) return '$count активных';
    return '$count активных';
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
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                const Text('Настройки', style: AppTextStyles.display),
                const SizedBox(height: AppSpacing.lg),
                // Статус-карточка подключения к Groq API
                if (!_loading && _keyCount > 0) ...[
                  _buildGroqStatusCard(),
                  const SizedBox(height: AppSpacing.md),
                ],
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
                          _loading ? '...' : _keyCountLabel(_keyCount),
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

  /// Статус-карточка «Подключено к Groq» — отображается когда ключ сохранён.
  Widget _buildGroqStatusCard() {
    return GlassTile(
      child: Row(
        children: [
          // Аватар-иконка ключа на accent-градиенте
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AppGradients.accent,
              borderRadius: BorderRadius.circular(AppRadius.icon),
            ),
            child: const Icon(
              Icons.vpn_key_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Заголовок и статус с зелёной точкой
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Подключено к Groq', style: AppTextStyles.heading),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    // Зелёная точка — индикатор активного ключа
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.good,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'API ключ активен',
                      style: AppTextStyles.label,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
