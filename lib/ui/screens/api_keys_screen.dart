import 'dart:ui';

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
    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Закрыть',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 260),
      transitionBuilder: (ctx, anim, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: child,
      ),
      pageBuilder: (ctx, _, __) {
        final palette = ctx.palette;
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Material(
              color: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    decoration: BoxDecoration(
                      color: palette.glassBgDeep,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: palette.glassRim, width: 0.5),
                      boxShadow: [palette.shadowDeep],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Удалить ключ?',
                          style: AppTextStyles.heading.copyWith(color: palette.ink1),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Это действие нельзя отменить.',
                          style: AppTextStyles.body.copyWith(color: palette.ink2),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: Text(
                                  'Отмена',
                                  style: AppTextStyles.label.copyWith(color: palette.ink1),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: Text(
                                  'Удалить',
                                  style: AppTextStyles.label.copyWith(color: palette.bad),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    if (confirmed == true) {
      await ref.read(apiKeyRepoProvider).removeKey(key.raw);
      ref.read(groqKeyPoolProvider).removeKey(key.raw);
      ref.invalidate(apiKeysProvider);
      await _loadKeys();
    }
  }

  Widget _buildKeysList() {
    final palette = context.palette;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_keys.isEmpty) {
      return Text(
        'Нет добавленных ключей',
        style: AppTextStyles.label.copyWith(color: palette.ink3),
      );
    }
    final pool = ref.read(groqKeyPoolProvider);
    return ListenableBuilder(
      listenable: pool,
      builder: (context, _) => Column(
        children: _keys.map((key) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: RepaintBoundary(
              child: GlassCard(
                flat: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Icon(Icons.vpn_key_outlined, size: 24, color: palette.ink2),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(key.masked, style: AppTextStyles.mono.copyWith(color: palette.ink1)),
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
                        color: palette.bad,
                        onPressed: () => _confirmDelete(key),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
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
                    Text('API-ключи', style: AppTextStyles.heading.copyWith(color: context.palette.ink1)),
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Groq API', style: AppTextStyles.heading.copyWith(color: palette.ink1)),
                            Text(
                              'Ключи хранятся в защищённом хранилище устройства',
                              style: AppTextStyles.label.copyWith(color: palette.ink2),
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
                            color: context.palette.ink3,
                          ),
                        ),
                        style: AppTextStyles.mono.copyWith(color: palette.ink1),
                        keyboardType: TextInputType.visiblePassword,
                        autocorrect: false,
                        enableSuggestions: false,
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _errorMessage!,
                          style: AppTextStyles.label.copyWith(
                            color: context.palette.bad,
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
                      color: context.palette.accent,
                      decoration: TextDecoration.underline,
                      decorationColor: context.palette.accent,
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
