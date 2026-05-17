import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/design_tokens.dart';
import '../../core/error/app_exception.dart';
import '../../core/storage/secure_storage_service.dart';
import '../../features/settings/api_key_repository.dart';
import '../../features/transcription/file_picker_service.dart';
import '../../features/transcription/selected_audio_file.dart';
import '../widgets/glass_icon_btn.dart';
import '../widgets/glass_tile.dart';
import '../widgets/gradient_background.dart';
import '../widgets/primary_button.dart';

/// Главный экран: empty state → file preview → кнопка «Транскрибировать».
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  SelectedAudioFile? _selectedFile;
  String? _errorMessage;
  bool _picking = false;

  Future<void> _onUploadTap() async {
    if (_picking) return;
    setState(() {
      _picking = true;
      _errorMessage = null;
    });
    try {
      final result = await const FilePickerService().pickAudioFile();
      switch (result) {
        case FilePickPicked(file: final f):
          if (mounted) setState(() => _selectedFile = f);
        case FilePickCancelled():
          break;
      }
    } on ValidationException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (_) {
      if (mounted) setState(() => _errorMessage = 'Не удалось открыть файл');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _onTranscribeTap() async {
    if (_selectedFile == null) return;

    // Pre-flight: есть ли хотя бы один API-ключ?
    final keys = await ApiKeyRepository(SecureStorageServiceImpl()).listKeys();
    if (!mounted) return;

    if (keys.isEmpty) {
      final goToSettings = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Добавьте API-ключ'),
          content: const Text('Для работы нужен ключ Groq. Это бесплатно.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Перейти в настройки'),
            ),
          ],
        ),
      );
      if (goToSettings == true && mounted) {
        Navigator.pushNamed(context, AppConstants.routeApiKeys);
      }
      return;
    }

    Navigator.pushNamed(
      context,
      AppConstants.routeProcessing,
      arguments: _selectedFile,
    );
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
                // Шапка: логотип + название + кнопка настроек
                Row(
                  children: [
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
                const Text('Расшифруй\nлюбой звук', style: AppTextStyles.display),
                const SizedBox(height: AppSpacing.md),
                // Subtitle
                Text(
                  'Загрузите аудиозапись лекции и получите готовый текст',
                  style: AppTextStyles.body.copyWith(color: AppColors.inkSecondary),
                ),
                const SizedBox(height: AppSpacing.xxl),
                // Upload card / file preview
                GestureDetector(
                  onTap: _picking ? null : _onUploadTap,
                  child: GlassTile(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: _selectedFile == null
                        ? _buildEmptyCard()
                        : _buildFilePreview(_selectedFile!),
                  ),
                ),
                // Сообщение об ошибке
                if (_errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _errorMessage!,
                    style: AppTextStyles.label.copyWith(color: AppColors.bad),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                // Кнопка «Транскрибировать»
                PrimaryButton(
                  label: 'Транскрибировать',
                  onPressed: _selectedFile == null
                      ? null
                      : () => _onTranscribeTap(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyCard() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: AppGradients.accent,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.upload_outlined, color: Colors.white, size: 36),
            ),
            if (_picking)
              const SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
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
    );
  }

  Widget _buildFilePreview(SelectedAudioFile file) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: AppGradients.accent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.audiotrack, color: Colors.white, size: 28),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                file.name,
                style: AppTextStyles.heading,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${file.sizeFormatted} · ${file.extension.toUpperCase()}',
                style: AppTextStyles.label,
              ),
            ],
          ),
        ),
        Text(
          'Заменить',
          style: AppTextStyles.label.copyWith(color: AppColors.accent),
        ),
      ],
    );
  }
}
