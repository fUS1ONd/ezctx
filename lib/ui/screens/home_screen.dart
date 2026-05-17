import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/design_tokens.dart';
import '../../core/error/app_exception.dart';
import '../../core/storage/secure_storage_service.dart';
import '../../features/settings/api_key_repository.dart';
import '../../features/transcription/audio_chunking_service.dart';
import '../../features/transcription/audio_metadata.dart';
import '../../features/transcription/file_picker_service.dart';
import '../../features/transcription/processing_args.dart';
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
  // Единственный экземпляр репозитория на весь lifecycle экрана.
  final ApiKeyRepository _repository = ApiKeyRepository(SecureStorageServiceImpl());

  SelectedAudioFile? _selectedFile;
  AudioMetadata? _metadata;
  bool _loadingMetadata = false;
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
          if (mounted) {
            setState(() {
              _selectedFile = f;
              _metadata = null;
              _loadingMetadata = false;
            });
            _loadMetadata(f);
          }
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

  /// Асинхронно загружает метаданные файла через ffprobe.
  /// Тихо обрабатывает ошибки — карточка показывается без длительности.
  Future<void> _loadMetadata(SelectedAudioFile file) async {
    if (!mounted) return;
    setState(() => _loadingMetadata = true);
    try {
      final meta = await AudioChunkingService().getMetadata(file.path);
      if (mounted) setState(() => _metadata = meta);
    } catch (_) {
      // Тихо: если ffprobe не удался, метаданные показываем без длительности.
    } finally {
      if (mounted) setState(() => _loadingMetadata = false);
    }
  }

  Future<void> _onTranscribeTap() async {
    if (_selectedFile == null) return;

    // Pre-flight: есть ли хотя бы один API-ключ?
    final keys = await _repository.listKeys();
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
      arguments: ProcessingArgs(file: _selectedFile!, metadata: _metadata),
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
                // Upload card / file preview — ConstrainedBox гарантирует minHeight=260
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: _picking ? null : _onUploadTap,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 260),
                      child: GlassTile(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: _selectedFile == null
                            ? _buildEmptyCard()
                            : _buildFilePreview(_selectedFile!),
                      ),
                    ),
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
            // Пунктирная рамка accent-цвета вокруг иконки загрузки
            CustomPaint(
              painter: _DashedBorderPainter(
                color: AppColors.accent.withValues(alpha: 0.55),
                strokeWidth: 1.5,
                dashWidth: 6,
                gapWidth: 4,
                borderRadius: 26,
              ),
              child: const SizedBox(width: 88, height: 88),
            ),
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
          'mp3, wav, m4a, ogg, flac',
          style: AppTextStyles.label,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        // Pill-метка «Из файлов» под подсказкой о форматах
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.pill)),
          ),
          child: Text(
            'Из файлов',
            style: AppTextStyles.label.copyWith(color: AppColors.accent),
          ),
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
              // Подстрока с размером и длительностью / индикатором загрузки.
              if (_loadingMetadata)
                Row(
                  children: [
                    Text(
                      '${file.sizeFormatted} · ${file.extension.toUpperCase()}',
                      style: AppTextStyles.label,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    ),
                  ],
                )
              else if (_metadata != null)
                Text(
                  '${_metadata!.sizeFormatted} · ${_metadata!.durationFormatted}',
                  style: AppTextStyles.label,
                )
              else
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

/// CustomPainter для пунктирной рамки с заданным радиусом скругления.
/// Рисует пунктир accent-цвета вокруг прямоугольника с rounded corners.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashWidth,
    required this.gapWidth,
    required this.borderRadius,
  });

  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double gapWidth;
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Путь вокруг скруглённого прямоугольника
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );

    final path = Path()..addRRect(rrect);

    // Вычисляем общую длину контура и рисуем пунктир
    final metrics = path.computeMetrics().toList();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = math.min(distance + dashWidth, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashWidth + gapWidth;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashWidth != dashWidth ||
        oldDelegate.gapWidth != gapWidth ||
        oldDelegate.borderRadius != borderRadius;
  }
}
