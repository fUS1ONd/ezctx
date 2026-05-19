import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/design_tokens.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/providers/theme_provider.dart';
import '../../features/transcription/transcription_options.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_background.dart';

/// Переработанный экран настроек: Подключение / Внешний вид / Уведомления.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  TranscriptionOptions _options = const TranscriptionOptions.defaults();

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    final saved = await ref.read(transcriptionOptionsRepoProvider).load();
    if (mounted) setState(() => _options = saved);
  }

  Future<void> _saveOptions(TranscriptionOptions updated) async {
    setState(() => _options = updated);
    await ref.read(transcriptionOptionsRepoProvider).save(updated);
  }

  String _keyCountLabel(int count) {
    if (count == 0) return 'Нет ключей';
    if (count == 1) return '1 активен';
    return '$count активных';
  }

  String _modelLabel(WhisperModel model) => switch (model) {
    WhisperModel.largeV3 => 'Whisper Large v3',
    WhisperModel.turbo => 'Whisper Turbo',
  };

  String _languageLabel(TranscriptionLanguage lang) => switch (lang) {
    TranscriptionLanguage.auto => 'Авто',
    TranscriptionLanguage.ru => 'Русский',
    TranscriptionLanguage.en => 'English',
    TranscriptionLanguage.de => 'Deutsch',
    TranscriptionLanguage.fr => 'Français',
    TranscriptionLanguage.es => 'Español',
    TranscriptionLanguage.uk => 'Українська',
    TranscriptionLanguage.zh => '中文',
    TranscriptionLanguage.ja => '日本語',
    TranscriptionLanguage.ko => '한국어',
    TranscriptionLanguage.ar => 'العربية',
  };

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final keysAsync = ref.watch(apiKeysProvider);
    final keyCountLabel = keysAsync.when(
      data: (keys) => _keyCountLabel(keys.length),
      loading: () => '...',
      error: (_, __) => '—',
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.md),
                const Text('Настройки', style: AppTextStyles.display),
                const SizedBox(height: AppSpacing.lg),

                // ── Блок «Подключение» ────────────────────────────────────
                Text(
                  'Подключение',
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.inkTertiary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                GlassCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.key_outlined,
                          color: AppColors.inkPrimary,
                        ),
                        title: const Text('API-ключи', style: AppTextStyles.body),
                        subtitle: Text(
                          keyCountLabel,
                          style: AppTextStyles.label,
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: AppColors.inkTertiary,
                        ),
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppConstants.routeApiKeys,
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(
                          Icons.graphic_eq_outlined,
                          color: AppColors.inkPrimary,
                        ),
                        title: const Text('Модель', style: AppTextStyles.body),
                        trailing: DropdownButton<WhisperModel>(
                          value: _options.model,
                          underline: const SizedBox.shrink(),
                          isDense: true,
                          items: WhisperModel.values
                              .map((m) => DropdownMenuItem(
                                    value: m,
                                    child: Text(
                                      _modelLabel(m),
                                      style: AppTextStyles.label,
                                    ),
                                  ))
                              .toList(),
                          onChanged: (m) {
                            if (m != null) {
                              _saveOptions(_options.copyWith(model: m));
                            }
                          },
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(
                          Icons.translate_outlined,
                          color: AppColors.inkPrimary,
                        ),
                        title: const Text('Язык', style: AppTextStyles.body),
                        trailing: DropdownButton<TranscriptionLanguage>(
                          value: _options.language,
                          underline: const SizedBox.shrink(),
                          isDense: true,
                          items: TranscriptionLanguage.values
                              .map((l) => DropdownMenuItem(
                                    value: l,
                                    child: Text(
                                      _languageLabel(l),
                                      style: AppTextStyles.label,
                                    ),
                                  ))
                              .toList(),
                          onChanged: (l) {
                            if (l != null) {
                              _saveOptions(_options.copyWith(language: l));
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // ── Блок «Внешний вид» ────────────────────────────────────
                Text(
                  'Внешний вид',
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.inkTertiary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                GlassCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Тема', style: AppTextStyles.body),
                      const SizedBox(height: AppSpacing.sm),
                      SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.system,
                            label: Text('Авто'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.light,
                            label: Text('Светлая'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            label: Text('Тёмная'),
                          ),
                        ],
                        selected: {themeMode},
                        onSelectionChanged: (sel) =>
                            ref.read(themeModeProvider.notifier).setTheme(sel.first),
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const Divider(height: AppSpacing.lg),
                      // Placeholder — реальная смена иконки требует activity-alias
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Иконка приложения', style: AppTextStyles.body),
                        subtitle: const Text(
                          'Ночная версия (скоро)',
                          style: AppTextStyles.label,
                        ),
                        value: false,
                        onChanged: null,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // ── Блок «Уведомления» ────────────────────────────────────
                Text(
                  'Уведомления',
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.inkTertiary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                GlassCard(
                  padding: EdgeInsets.zero,
                  child: SwitchListTile(
                    title: const Text(
                      'Уведомления о завершении',
                      style: AppTextStyles.body,
                    ),
                    subtitle: const Text(
                      'Скоро',
                      style: AppTextStyles.label,
                    ),
                    value: false,
                    onChanged: null,
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
