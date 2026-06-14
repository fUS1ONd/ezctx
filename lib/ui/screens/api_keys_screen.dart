import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/design_tokens.dart';
import '../../core/error/app_exception.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/providers/service_providers.dart';
import '../../features/settings/api_key_repository.dart';
import '../../features/transcription/key_pool.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_confirm_dialog.dart';
import '../widgets/glass_icon_btn.dart';
import '../widgets/glass_tile.dart';
import '../widgets/gradient_background.dart';
import '../widgets/key_status_tile.dart';
import '../widgets/liquid_glass_tab_bar.dart';
import '../widgets/primary_button.dart';

/// Экран управления API-ключами с двумя вкладками: Groq и Deepgram.
///
/// Принимает [initialTab] ('groq' или 'deepgram') — задаёт активную вкладку при открытии.
/// Используется из app.dart через Navigator.arguments (D-08).
class ApiKeysScreen extends ConsumerStatefulWidget {
  /// Начальная вкладка: 'groq' (по умолчанию) или 'deepgram'.
  final String initialTab;

  const ApiKeysScreen({super.key, this.initialTab = 'groq'});

  @override
  ConsumerState<ApiKeysScreen> createState() => _ApiKeysScreenState();
}

class _ApiKeysScreenState extends ConsumerState<ApiKeysScreen> {
  /// Индекс активной вкладки: 0 = Groq, 1 = Deepgram.
  late int _activeTabIndex;

  @override
  void initState() {
    super.initState();
    // Инициализируем индекс вкладки по параметру initialTab
    _activeTabIndex = widget.initialTab == 'deepgram' ? 1 : 0;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.md),
              // Шапка с кнопкой «Назад» и заголовком
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Row(
                  children: [
                    GlassIconBtn(
                      icon: Icons.arrow_back,
                      semanticLabel: 'Назад',
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'API-ключи',
                      style: AppTextStyles.heading.copyWith(color: palette.ink1),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              // Таббар Groq / Deepgram (text-only, icon не передаётся — D-08)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: LiquidGlassTabBar(
                  activeIndex: _activeTabIndex,
                  onChanged: (i) => setState(() => _activeTabIndex = i),
                  margin: EdgeInsets.zero,
                  items: const [
                    TabItem(label: 'Groq'),
                    TabItem(label: 'Deepgram'),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              // Контент активной вкладки с анимацией переключения 180ms (UI-SPEC §Animation)
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeOut,
                  child: _activeTabIndex == 0
                      ? _KeysTabContent(
                          key: const ValueKey(0),
                          repoProvider: apiKeyRepoProvider,
                          poolProvider: groqKeyPoolProvider,
                          keysProvider: apiKeysProvider,
                          hintText: 'gsk_•••••••••••••••••••••...',
                          getKeyUrl: 'https://console.groq.com/keys',
                          getKeyLabel: 'Получить ключ на console.groq.com',
                        )
                      : _KeysTabContent(
                          key: const ValueKey(1),
                          repoProvider: deepgramApiKeyRepoProvider,
                          poolProvider: deepgramKeyPoolProvider,
                          keysProvider: deepgramApiKeysProvider,
                          hintText: '••••••••••••••••...',
                          getKeyUrl: 'https://console.deepgram.com',
                          getKeyLabel: 'Получить ключ на deepgram.com',
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Переиспользуемый контент вкладки управления ключами.
///
/// Инкапсулирует всю логику добавления/удаления/отображения ключей
/// для любого провайдера (Groq или Deepgram).
/// Anti-pattern дублирования отдельных экранов-вкладок здесь не применяется.
///
/// Параметры:
/// - [repoProvider] — провайдер репозитория (apiKeyRepoProvider / deepgramApiKeyRepoProvider)
/// - [poolProvider] — провайдер пула ключей (groqKeyPoolProvider / deepgramKeyPoolProvider)
/// - [keysProvider] — FutureProvider списка ключей (apiKeysProvider / deepgramApiKeysProvider)
/// - [hintText] — placeholder в поле ввода нового ключа
/// - [getKeyUrl] — URL консоли провайдера
/// - [getKeyLabel] — текст ссылки на консоль
class _KeysTabContent extends ConsumerStatefulWidget {
  final Provider<ApiKeyRepository> repoProvider;
  final Provider<KeyPool> poolProvider;
  final FutureProvider<List<ApiKeyView>> keysProvider;
  final String hintText;
  final String getKeyUrl;
  final String getKeyLabel;

  const _KeysTabContent({
    super.key,
    required this.repoProvider,
    required this.poolProvider,
    required this.keysProvider,
    required this.hintText,
    required this.getKeyUrl,
    required this.getKeyLabel,
  });

  @override
  ConsumerState<_KeysTabContent> createState() => _KeysTabContentState();
}

class _KeysTabContentState extends ConsumerState<_KeysTabContent> {
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

  /// Загружает список ключей из репозитория текущей вкладки.
  Future<void> _loadKeys() async {
    setState(() => _loading = true);
    final keys = await ref.read(widget.repoProvider).listKeys();
    if (mounted) {
      setState(() {
        _keys = keys;
        _loading = false;
      });
    }
  }

  /// Добавляет новый ключ в репозиторий и пул текущей вкладки.
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
      // Сохраняем в защищённом хранилище и добавляем в пул ротации
      await ref.read(widget.repoProvider).addKey(rawKey);
      // CR-03: проверяем mounted после первого await перед setState/ref
      if (!mounted) return;
      ref.read(widget.poolProvider).addKey(rawKey);
      _inputController.clear();
      ref.invalidate(widget.keysProvider);
      await _loadKeys();
    } on ValidationException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Не удалось сохранить ключ');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Диалог подтверждения удаления ключа.
  Future<void> _confirmDelete(ApiKeyView key) async {
    final confirmed = await GlassConfirmDialog.show(
      context,
      title: 'Удалить ключ?',
      body: 'Это действие нельзя отменить.',
      confirmLabel: 'Удалить',
    );
    if (confirmed) {
      // CR-01: проверяем mounted после await диалога перед обращением к ref/setState
      if (!mounted) return;
      // Удаляем из хранилища и из пула ротации текущей вкладки
      await ref.read(widget.repoProvider).removeKey(key.raw);
      ref.read(widget.poolProvider).removeKey(key.raw);
      ref.invalidate(widget.keysProvider);
      await _loadKeys();
    }
  }

  /// Строит список ключей с KeyStatusTile для отображения Active/Blocked/Exhausted (Plan 01).
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
    // Читаем пул текущей вкладки для отображения статусов (T-11-05: raw не отображается)
    final pool = ref.read(widget.poolProvider);
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
                      // T-11-05: отображаем только маскированный ключ, не raw
                      child: Text(
                        key.masked,
                        style: AppTextStyles.mono.copyWith(color: palette.ink1),
                      ),
                    ),
                    // Статус Active/Blocked/Exhausted — из Plan 01
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
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Карточка-заголовок — информация о безопасном хранении
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
                  child: Text(
                    'Ключи хранятся в защищённом хранилище устройства',
                    style: AppTextStyles.label.copyWith(color: palette.ink2),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildKeysList(),
          const SizedBox(height: AppSpacing.lg),
          // Поле ввода нового ключа (T-11-06: visiblePassword без автокоррекции)
          GlassCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _inputController,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: widget.hintText,
                    hintStyle: AppTextStyles.mono.copyWith(
                      color: context.palette.ink3,
                    ),
                  ),
                  style: AppTextStyles.mono.copyWith(color: palette.ink1),
                  // T-11-06: без автоподсказок/буфера клавиатуры для безопасности
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
          // Ссылка на консоль провайдера для получения ключа
          GestureDetector(
            onTap: () async {
              // CR-02: await + обработка ошибки, чтобы не игнорировать сбой запуска URL
              try {
                await launchUrl(
                  Uri.parse(widget.getKeyUrl),
                  mode: LaunchMode.externalApplication,
                );
              } catch (_) {
                // Не можем открыть браузер — игнорируем молча, URL отображён пользователю
              }
            },
            child: Text(
              widget.getKeyLabel,
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
    );
  }
}
