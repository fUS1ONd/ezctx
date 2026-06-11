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
import '../../features/transcription/transcription_options.dart';
import '../widgets/file_card.dart';
import '../widgets/gradient_background.dart';
import '../widgets/no_keys_dialog.dart';
import '../widgets/scaffold_with_nav_bar.dart';
import '../widgets/theme_toggle_button.dart';

/// Главный экран. Изменения относительно предыдущей версии:
///  • CTA «Транскрибировать» живёт ВНУТРИ карточки файла (не плавающий внизу).
///  • Карточка с файлом ужимается до контента; пустая карточка занимает
///    оставшееся место (с dashed dropzone).
///  • Кнопка переключения темы заменила шестерню в шапке.
///  • Баннер «нет ключей» убран — вместо него полноэкранная liquid-модалка
///    срабатывает по тапу на CTA (когда ключей нет).
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
      final meta = await ref
          .read(audioChunkingServiceProvider)
          .getMetadata(file.path);
      if (mounted) setState(() => _metadata = meta);
    } catch (_) {
      // Тихо: если ffprobe не удался, метаданные показываем без длительности.
    } finally {
      if (mounted) setState(() => _loadingMetadata = false);
    }
  }

  Future<void> _onTranscribeTap() async {
    if (_selectedFile == null) return;

    // Опции грузим ПЕРВЫМИ: провайдер ключей определяется выбранной моделью.
    // Groq и Deepgram хранят ключи в разных namespace — нельзя проверять
    // только Groq, иначе при выбранной nova3 (Deepgram) приложение требует
    // несуществующий Groq-ключ.
    final options = await ref.read(transcriptionOptionsRepoProvider).load();
    if (!mounted) return;

    final isDeepgram =
        options.model.provider == TranscriptionProviderId.deepgram;
    final keyRepo = isDeepgram
        ? ref.read(deepgramApiKeyRepoProvider)
        : ref.read(apiKeyRepoProvider);
    final keys = await keyRepo.listKeys();
    if (!mounted) return;

    if (keys.isEmpty) {
      // Для Deepgram показываем провайдер-специфичный текст; для Groq —
      // дефолтные title/bodyText диалога.
      final bool? goToSettings;
      if (isDeepgram) {
        goToSettings = await NoKeysDialog.show(
          context,
          title: 'Нужен ключ Deepgram',
          bodyText: 'Nova-3 работает через Deepgram. Добавьте '
              'API-ключ Deepgram — free-tier хватает на часы аудио.',
        );
      } else {
        goToSettings = await NoKeysDialog.show(context);
      }
      if (!mounted) return;
      if (goToSettings == true) {
        ScaffoldWithNavBar.of(context)?.switchTab(2);
      }
      return;
    }

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
    final palette = context.palette;

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

                // ── Шапка: лого + название + кнопка темы ──
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: AppGradients.accent,
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: [
                          BoxShadow(
                            color: palette.accent.withValues(alpha: 0.28),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Слух',
                      style: AppTextStyles.heading.copyWith(color: palette.ink1),
                    ),
                    const Spacer(),
                    const ThemeToggleButton(),
                  ],
                ),

                const SizedBox(height: AppSpacing.xl),

                // ── Заголовок и подзаголовок ──
                Text(
                  'Расшифруй\nлюбой звук',
                  style: AppTextStyles.display.copyWith(color: palette.ink1),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Загрузите аудиозапись и через пару минут получите готовый текст.',
                  style: AppTextStyles.body.copyWith(color: palette.ink2),
                ),

                const SizedBox(height: AppSpacing.lg),

                // ── Содержимое ──
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _selectedFile == null
                        ? _EmptyDropzone(
                            picking: _picking,
                            onTap: _onUploadTap,
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              FileCard(
                                file: _selectedFile!,
                                metadata: _metadata,
                                loadingMetadata: _loadingMetadata,
                                onReplace: _onUploadTap,
                                onTranscribe: _onTranscribeTap,
                              ),
                              if (_errorMessage != null) ...[
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  _errorMessage!,
                                  style: AppTextStyles.label
                                      .copyWith(color: palette.bad),
                                ),
                              ],
                            ],
                          ),
                  ),
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
}

/// Пустое состояние с пунктирной dropzone-рамкой. Растягивается на доступное
/// пространство, центрирует содержимое.
class _EmptyDropzone extends StatelessWidget {
  const _EmptyDropzone({required this.picking, required this.onTap});

  final bool picking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return GestureDetector(
      onTap: picking ? null : onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: palette.glassBg,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: palette.glassRim, width: 0.5),
            boxShadow: [palette.shadow],
          ),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      painter: _DashedBorderPainter(
                        color: palette.accent.withValues(alpha: 0.55),
                        strokeWidth: 1.5,
                        dashWidth: 6,
                        gapWidth: 4,
                        borderRadius: 26,
                      ),
                      child: const SizedBox(width: 112, height: 112),
                    ),
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        gradient: AppGradients.accent,
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: palette.accent.withValues(alpha: 0.34),
                            blurRadius: 24,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.upload_outlined,
                          color: Colors.white, size: 36),
                    ),
                    if (picking)
                      const SizedBox(
                        width: 100,
                        height: 100,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Выберите файл',
                  style: AppTextStyles.heading.copyWith(color: palette.ink1)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'mp3 · wav · m4a · ogg · flac',
                style: AppTextStyles.label.copyWith(color: palette.ink2),
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: palette.accent.withValues(alpha: 0.12),
                  borderRadius:
                      const BorderRadius.all(Radius.circular(AppRadius.pill)),
                ),
                child: Text(
                  'Из файлов',
                  style: AppTextStyles.label.copyWith(
                    color: palette.accent,
                    fontWeight: FontWeight.w600,
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

    for (final metric in path.computeMetrics().toList()) {
      double distance = 0;
      while (distance < metric.length) {
        final end = math.min(distance + dashWidth, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashWidth + gapWidth;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) {
    return old.color != color ||
        old.strokeWidth != strokeWidth ||
        old.dashWidth != dashWidth ||
        old.gapWidth != gapWidth ||
        old.borderRadius != borderRadius;
  }
}
