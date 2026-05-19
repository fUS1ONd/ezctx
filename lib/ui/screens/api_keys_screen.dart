import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/design_tokens.dart';
import '../../core/error/app_exception.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/providers/service_providers.dart';
import '../../features/settings/api_key_repository.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_icon_btn.dart';
import '../widgets/glass_tile.dart';
import '../widgets/gradient_background.dart';
import '../widgets/key_status_tile.dart';
import '../widgets/primary_button.dart';

/// Экран управления API-ключами Groq.
class ApiKeysScreen extends ConsumerStatefulWidget {
  const ApiKeysScreen({super.key});

  @override
  ConsumerState<ApiKeysScreen> createState() => _ApiKeysScreenState();
}

class _ApiKeysScreenState extends ConsumerState<ApiKeysScreen> {
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
    final keys = await ref.read(apiKeyRepoProvider).listKeys();
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
    final rawKey = _inputController.text.trim();
    if (rawKey.isEmpty) {
      setState(() {
        _errorMessage = 'Ключ не может быть пустым';
        _saving = false;
      });
      return;
    }
    try {
      await ref.read(apiKeyRepoProvider).addKey(rawKey);
      ref.read(groqKeyPoolProvider).addKey(rawKey);
      _inputController.clear();
      ref.invalidate(apiKeysProvider);
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
      await ref.read(apiKeyRepoProvider).removeKey(key.raw);
      ref.read(groqKeyPoolProvider).removeKey(key.raw);
      ref.invalidate(apiKeysProvider);
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
    final pool = ref.read(groqKeyPoolProvider);
    return ListenableBuilder(
      listenable: pool,
      builder: (context, _) => Column(
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
                  const Icon(Icons.vpn_key_outlined, size: 24, color: AppColors.inkSecondary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(key.masked, style: AppTextStyles.mono),
                  ),
                  KeyStatusTile(
                    status: pool.getStatusForKey(key.raw),
                  ),
                  const SizedBox(width: AppSpacing.sm),
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
      ),
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
                _buildKeysList(),
                const SizedBox(height: AppSpacing.lg),
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
