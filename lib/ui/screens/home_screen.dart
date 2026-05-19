import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/design_tokens.dart';
import '../../core/error/app_exception.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/providers/service_providers.dart';
import '../../features/transcription/audio_metadata.dart';
import '../../features/transcription/file_picker_service.dart';
import '../../features/transcription/processing_args.dart';
import '../../features/transcription/selected_audio_file.dart';
import '../widgets/glass_tile.dart';
import '../widgets/glass_icon_btn.dart';
import '../widgets/gradient_background.dart';
import '../widgets/primary_button.dart';
import '../widgets/scaffold_with_nav_bar.dart';

/// Главный экран: empty state → file preview → кнопка «Транскрибировать».
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
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
      final result = await ref.read(filePickerServiceProvider).pickAudioFile();
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

  Future<void> _loadMetadata(SelectedAudioFile file) async {
    if (!mounted) return;
    setState(() => _loadingMetadata = true);
    try {
      final meta = await ref.read(audioChunkingServiceProvider).getMetadata(file.path);
      if (mounted) setState(() => _metadata = meta);
    } catch (_) {
      // Тихо: если ffprobe не удался, метаданные показываем без длительности.
    } finally {
      if (mounted) setState(() => _loadingMetadata = false);
    }
  }

  Future<void> _onTranscribeTap() async {
    if (_selectedFile == null) return;

    final keys = await ref.read(apiKeyRepoProvider).listKeys();
    if (!mounted) return;

    if (keys.isEmpty) {
      ScaffoldWithNavBar.of(context)?.switchTab(2);
      return;
    }

    final options = await ref.read(transcriptionOptionsRepoProvider).load();
    if (!mounted) return;

    Navigator.pushNamed(
      context,
      AppConstants.routeProcessing,
      arguments: ProcessingArgs(
        file: _selectedFile!,
        metadata: _metadata,
        options: options,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keysAsync = ref.watch(apiKeysProvider);
    final hasNoKeys = keysAsync.maybeWhen(
      data: (keys) => keys.isEmpty,
      orElse: () => false,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppSpacing.md),
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
                                  ScaffoldWithNavBar.of(context)?.switchTab(2),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        const Text('Расшифруй\nлюбой звук', style: AppTextStyles.display),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Загрузите аудиозапись лекции и получите готовый текст',
                          style: AppTextStyles.body.copyWith(color: AppColors.inkSecondary),
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // Баннер «нет ключей» — появляется реактивно
                        if (hasNoKeys) ...[
                          _buildNoKeysBanner(),
                          const SizedBox(height: AppSpacing.md),
                        ],

                        const SizedBox(height: AppSpacing.md),
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
                        if (_errorMessage != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            _errorMessage!,
                            style: AppTextStyles.label.copyWith(color: AppColors.bad),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.xl),
                      ],
                    ),
                  ),
                ),
                PrimaryButton(
                  label: 'Транскрибировать',
                  onPressed: _selectedFile == null
                      ? null
                      : () => _onTranscribeTap(),
                ),
                // Отступ под капсулу LiquidGlassTabBar (48 высота + 30 margin).
                const SizedBox(height: 96),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoKeysBanner() {
    return GlassTile(
      child: Row(
        children: [
          const Icon(
            Icons.key_off_outlined,
            color: AppColors.accent,
            size: 28,
          ),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: Text(
              'Добавьте API-ключ Groq для транскрибации',
              style: AppTextStyles.body,
            ),
          ),
          TextButton(
            onPressed: () => ScaffoldWithNavBar.of(context)?.switchTab(2),
            child: Text(
              'Открыть настройки',
              style: AppTextStyles.label.copyWith(color: AppColors.accent),
            ),
          ),
        ],
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

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );

    final path = Path()..addRRect(rrect);

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
