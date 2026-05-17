import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/design_tokens.dart';
import '../../core/error/app_exception.dart';
import '../../core/storage/secure_storage_service.dart';
import '../../features/settings/api_key_repository.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_icon_btn.dart';
import '../widgets/glass_tile.dart';
import '../widgets/gradient_background.dart';
import '../widgets/primary_button.dart';

/// Экран управления API-ключами Groq.
/// Поддерживает добавление, маскированное отображение и удаление ключей.
class ApiKeysScreen extends StatefulWidget {
  const ApiKeysScreen({super.key});

  @override
  State<ApiKeysScreen> createState() => _ApiKeysScreenState();
}

class _ApiKeysScreenState extends State<ApiKeysScreen> {
  // Единственный экземпляр репозитория на весь lifecycle экрана.
  final ApiKeyRepository _repository = ApiKeyRepository(SecureStorageServiceImpl());

  List<ApiKeyView> _keys = [];
  bool _loading = true;
  String? _errorMessage;
  final TextEditingController _inputController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _loadKeys() async {
    setState(() => _loading = true);
    final keys = await _repository.listKeys();
    if (mounted) {
      setState(() {
        _keys = keys;
        _loading = false;
      });
    }
  }

  Future<void> _onAddPressed() async {
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      await _repository.addKey(_inputController.text);
      _inputController.clear();
      await _loadKeys();
    } on ValidationException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Не удалось сохранить ключ');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete(ApiKeyView key) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить ключ?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.bad),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _repository.removeKey(key.raw);
      await _loadKeys();
    }
  }

  Widget _buildKeysList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_keys.isEmpty) {
      return Text(
        'Нет добавленных ключей',
        style: AppTextStyles.label.copyWith(color: AppColors.inkTertiary),
      );
    }
    return Column(
      children: _keys.map((key) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(Icons.vpn_key_outlined, size: 24, color: AppColors.inkSecondary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(key.masked, style: AppTextStyles.mono),
                ),
                Semantics(
                  label: 'Удалить ключ',
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: AppColors.bad,
                    onPressed: () => _confirmDelete(key),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.md),
                // Шапка
                Row(
                  children: [
                    GlassIconBtn(
                      icon: Icons.arrow_back,
                      semanticLabel: 'Назад',
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const Text('API-ключи', style: AppTextStyles.heading),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                // Hero-карточка Groq
                GlassTile(
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: AppGradients.accent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.key_outlined,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Groq API', style: AppTextStyles.heading),
                            Text(
                              'Ключи хранятся в защищённом хранилище устройства',
                              style: AppTextStyles.label,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                // Список ключей
                _buildKeysList(),
                const SizedBox(height: AppSpacing.lg),
                // Форма добавления
                GlassCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _inputController,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'gsk_••••••••••••••••••••...',
                          hintStyle: AppTextStyles.mono.copyWith(
                            color: AppColors.inkTertiary,
                          ),
                        ),
                        style: AppTextStyles.mono,
                        keyboardType: TextInputType.visiblePassword,
                        autocorrect: false,
                        enableSuggestions: false,
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _errorMessage!,
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.bad,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      PrimaryButton(
                        label: _saving ? 'Сохранение...' : 'Добавить ключ',
                        onPressed: _saving ? null : _onAddPressed,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // Footer
                GestureDetector(
                  onTap: () => launchUrl(
                    Uri.parse('https://console.groq.com/keys'),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: Text(
                    'Получить ключ на console.groq.com',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.accent,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.accent,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
