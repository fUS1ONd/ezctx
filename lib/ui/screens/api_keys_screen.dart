import 'package:flutter/material.dart';

import '../../core/constants/design_tokens.dart';
import '../../core/storage/secure_storage_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_icon_btn.dart';
import '../widgets/glass_tile.dart';
import '../widgets/gradient_background.dart';
import '../widgets/primary_button.dart';

// TODO(Plan 02): заменить skeleton-поле и кнопку 'Сохранить тестовое значение'
// на UI с маскированием, валидацией и удалением.

/// Экран управления API-ключами.
/// В Plan 01 — skeleton с реальным read/write в flutter_secure_storage.
class ApiKeysScreen extends StatefulWidget {
  const ApiKeysScreen({super.key});

  @override
  State<ApiKeysScreen> createState() => _ApiKeysScreenState();
}

class _ApiKeysScreenState extends State<ApiKeysScreen> {
  final TextEditingController _controller = TextEditingController();
  String? _currentValue;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadCurrentValue);
  }

  Future<void> _loadCurrentValue() async {
    final value = await SecureStorageServiceImpl().readRawKey();
    if (mounted) {
      setState(() {
        _currentValue = value;
        _controller.text = value ?? '';
        _isLoading = false;
      });
    }
  }

  Future<void> _onSave() async {
    final valueToSave =
        _controller.text.isEmpty ? 'skeleton-test-key' : _controller.text;
    await SecureStorageServiceImpl().writeRawKey(valueToSave);
    final newValue = await SecureStorageServiceImpl().readRawKey();
    if (mounted) {
      setState(() {
        _currentValue = newValue;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сохранено'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Groq API', style: AppTextStyles.heading),
                          Text(
                            _isLoading
                                ? 'Загрузка...'
                                : (_currentValue != null
                                      ? 'Ключ сохранён'
                                      : 'Нет ключа'),
                            style: AppTextStyles.label.copyWith(
                              color: _currentValue != null
                                  ? AppColors.good
                                  : AppColors.inkTertiary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // Поле ввода ключа (glass deep variant)
                GlassCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Введите API-ключ',
                      hintStyle: AppTextStyles.body.copyWith(
                        color: AppColors.inkTertiary,
                      ),
                    ),
                    style: AppTextStyles.body,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // Кнопка сохранения
                PrimaryButton(
                  label: 'Сохранить тестовое значение',
                  onPressed: _onSave,
                ),
                const SizedBox(height: AppSpacing.md),
                // Отображение текущего значения (skeleton верификация)
                Text(
                  'Текущее значение: ${_currentValue ?? 'не сохранено'}',
                  style: AppTextStyles.label,
                ),
                const SizedBox(height: AppSpacing.sm),
                // Подсказка безопасности
                Text(
                  'Ключ хранится в защищённом хранилище устройства',
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.inkTertiary,
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
