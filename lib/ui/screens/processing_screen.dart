import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/design_tokens.dart';
import '../../core/providers/service_providers.dart';
import '../../features/transcription/audio_chunking_service.dart';
import '../../features/transcription/audio_normalization_service.dart';
import '../../features/transcription/chunked_transcription_controller.dart';
import '../../features/transcription/groq_api_service.dart';
import '../../features/transcription/normalized_audio_file.dart';
import '../../features/transcription/processing_args.dart';
import '../../features/transcription/result_args.dart';
import '../../features/transcription/selected_audio_file.dart';
import '../../features/transcription/transcription_options.dart';
import '../widgets/chunk_tile.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_icon_btn.dart';
import '../widgets/glass_tile.dart';
import '../widgets/gradient_background.dart';
import '../widgets/primary_button.dart';
import '../widgets/shimmer_bar.dart';

/// Экран обработки: запускает транскрибацию, показывает pipeline, обрабатывает ошибки.
class ProcessingScreen extends ConsumerStatefulWidget {
  const ProcessingScreen({super.key});

  @override
  ConsumerState<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends ConsumerState<ProcessingScreen>
    with SingleTickerProviderStateMixin {
  ChunkedTranscriptionController? _chunkedController;

  bool _normalizing = false;
  NormalizedAudioFile? _normalizedFile;
  String? _normalizationError;

  /// Настройки транскрибации, переданные с HomeScreen через ProcessingArgs.
  TranscriptionOptions _transcriptionOptions = const TranscriptionOptions.defaults();

  SelectedAudioFile? _file;
  DateTime? _startedAt;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;

  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    final curved = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(curved);
    _opacityAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(curved);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_file == null) {
      final args = ModalRoute.of(context)?.settings.arguments;

      SelectedAudioFile? file;
      if (args is ProcessingArgs) {
        file = args.file;
        _transcriptionOptions = args.options;
      } else if (args is SelectedAudioFile) {
        file = args;
      }

      if (file != null) {
        _file = file;
        _startedAt = DateTime.now();
        _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) {
            setState(() => _elapsed = DateTime.now().difference(_startedAt!));
          }
        });

        WidgetsBinding.instance.addPostFrameCallback((_) => _startProcessing());
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
        });
      }
    }
  }

  Future<void> _startProcessing() async {
    if (!mounted) return;
    setState(() {
      _normalizing = true;
      _normalizationError = null;
    });

    try {
      _normalizedFile = await AudioNormalizationService().normalize(_file!.path);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _normalizing = false;
        _normalizationError = 'Ошибка подготовки аудио: $e';
      });
      return;
    }

    if (!mounted) return;
    setState(() => _normalizing = false);

    _chunkedController = ChunkedTranscriptionController(
      pool: ref.read(groqKeyPoolProvider),
      apiService: GroqApiService(),
      chunkingService: AudioChunkingService(),
    );
    _chunkedController!.addListener(_onChunkedStateChange);
    await _chunkedController!.start(_normalizedFile!, options: _transcriptionOptions);
  }

  void _onChunkedStateChange() {
    final s = _chunkedController?.state;
    if (s is ChunkedSuccess) {
      _ticker?.cancel();
      if (mounted) {
        setState(() {});
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            Navigator.pushReplacementNamed(
              context,
              AppConstants.routeResult,
              arguments: ResultArgs(file: _file!, result: s.result),
            );
          }
        });
      }
      return;
    }
    if (mounted) setState(() {});
  }

  void _restart() {
    _ticker?.cancel();
    _chunkedController?.removeListener(_onChunkedStateChange);
    _chunkedController?.dispose();
    setState(() {
      _elapsed = Duration.zero;
      _startedAt = DateTime.now();
      _normalizationError = null;
      _normalizedFile = null;
      _chunkedController = null;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed = DateTime.now().difference(_startedAt!));
    });
    _startProcessing();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pulseController.dispose();
    _chunkedController?.removeListener(_onChunkedStateChange);
    _chunkedController?.dispose();
    if (_normalizedFile != null) {
      try {
        File(_normalizedFile!.path).deleteSync();
      } catch (_) {}
    }
    super.dispose();
  }

  String _formatElapsed(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final chunkedState = _chunkedController?.state;

    final _PipelineStatus recognitionStatus = switch (chunkedState) {
      ChunkedProcessing() || ChunkedSplitting() => _PipelineStatus.active,
      ChunkedSuccess() => _PipelineStatus.done,
      ChunkedError() => _PipelineStatus.error,
      _ => _normalizedFile != null ? _PipelineStatus.active : _PipelineStatus.pending,
    };

    final bool isDone = chunkedState is ChunkedSuccess;
    final bool showShimmer = _normalizing;

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
                Row(
                  children: [
                    GlassIconBtn(
                      icon: Icons.close,
                      semanticLabel: 'Закрыть',
                      onPressed: () =>
                          Navigator.popUntil(context, (r) => r.isFirst),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const Text('Обработка', style: AppTextStyles.heading),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),

                if (_file != null)
                  GlassTile(
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: AppGradients.accent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.audiotrack,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _file!.name,
                                style: AppTextStyles.heading,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${_file!.sizeFormatted} · ${_file!.extension.toUpperCase()}',
                                style: AppTextStyles.label,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: AppSpacing.lg),

                if (showShimmer) ...[
                  const ShimmerBar(),
                  const SizedBox(height: AppSpacing.sm),
                  if (_normalizing)
                    Text(
                      'Подготовка аудио…',
                      style: AppTextStyles.body
                          .copyWith(color: AppColors.inkSecondary),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                ],

                Expanded(
                  child: SingleChildScrollView(
                    child: GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPipelineStep(
                            label: 'Загрузка',
                            status: _PipelineStatus.done,
                          ),
                          const Divider(height: AppSpacing.lg),
                          _buildPipelineStep(
                            label: 'Подготовка аудио',
                            status: _normalizing
                                ? _PipelineStatus.active
                                : (_normalizedFile != null
                                    ? _PipelineStatus.done
                                    : (_normalizationError != null
                                        ? _PipelineStatus.error
                                        : _PipelineStatus.pending)),
                          ),
                          const Divider(height: AppSpacing.lg),
                          _buildPipelineStep(
                            label: 'Распознавание',
                            status: recognitionStatus,
                            inlineContent: chunkedState != null
                                ? _buildChunkedInline(chunkedState)
                                : null,
                          ),
                          const Divider(height: AppSpacing.lg),
                          _buildPipelineStep(
                            label: 'Готово',
                            status: isDone
                                ? _PipelineStatus.done
                                : _PipelineStatus.pending,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                if (_normalizationError != null)
                  _buildNormalizationError(_normalizationError!),

                if (_normalizationError == null)
                  _buildChunkedBottomBar(chunkedState),

                SizedBox(height: MediaQuery.of(context).padding.bottom + 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChunkedInline(ChunkedState state) {
    return switch (state) {
      ChunkedSplitting() => Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ShimmerBar(),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Разбиваем на чанки…',
                style: AppTextStyles.body.copyWith(color: AppColors.inkSecondary),
              ),
            ],
          ),
        ),

      ChunkedProcessing(:final chunks, :final completedCount, :final totalCount) =>
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: LinearProgressIndicator(
                  value: totalCount == 0 ? 0.0 : completedCount / totalCount,
                  minHeight: 6,
                  backgroundColor: AppColors.inkDivider,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '$completedCount из $totalCount чанков',
                style: AppTextStyles.label,
              ),
              const SizedBox(height: AppSpacing.sm),
              ExpansionTile(
                title: Text(
                  'Детали чанков',
                  style: AppTextStyles.label,
                ),
                initiallyExpanded: true,
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                children: [
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: chunks.length,
                    itemBuilder: (context, i) => ChunkTile(state: chunks[i]),
                  ),
                ],
              ),
            ],
          ),
        ),

      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildChunkedBottomBar(ChunkedState? state) {
    return switch (state) {
      ChunkedSplitting() || ChunkedProcessing() => GlassCard(
          borderRadius: AppRadius.pill,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatElapsed(_elapsed), style: AppTextStyles.mono),
              TextButton(
                onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                child: Text(
                  'Отменить обработку',
                  style: AppTextStyles.label.copyWith(color: AppColors.bad),
                ),
              ),
            ],
          ),
        ),

      ChunkedError(:final message, :final retryable) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              message,
              style: AppTextStyles.label.copyWith(color: AppColors.bad),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (retryable && _file != null)
              PrimaryButton(
                label: 'Повторить',
                onPressed: () {
                  if (_normalizedFile != null) {
                    _chunkedController?.start(
                      _normalizedFile!,
                      options: _transcriptionOptions,
                    );
                  }
                },
              ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
              child: const Text('Назад'),
            ),
          ],
        ),

      ChunkedMissingKey() => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Добавьте API-ключ Groq для начала транскрибации',
              style: AppTextStyles.label.copyWith(color: AppColors.bad),
            ),
            const SizedBox(height: AppSpacing.sm),
            PrimaryButton(
              label: 'Перейти в настройки',
              onPressed: () =>
                  Navigator.pushNamed(context, AppConstants.routeApiKeys),
            ),
          ],
        ),

      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildNormalizationError(String message) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          message,
          style: AppTextStyles.label.copyWith(color: AppColors.bad),
        ),
        const SizedBox(height: AppSpacing.sm),
        PrimaryButton(
          label: 'Повторить',
          onPressed: _restart,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
          child: const Text('Назад'),
        ),
      ],
    );
  }

  Widget _buildPipelineStep({
    required String label,
    required _PipelineStatus status,
    Widget? inlineContent,
  }) {
    final Color dotColor;
    final IconData? icon;

    switch (status) {
      case _PipelineStatus.done:
        dotColor = AppColors.good;
        icon = Icons.check;
      case _PipelineStatus.active:
        dotColor = AppColors.accent;
        icon = null;
      case _PipelineStatus.error:
        dotColor = AppColors.bad;
        icon = Icons.error_outline;
      case _PipelineStatus.pending:
        dotColor = AppColors.inkTertiary;
        icon = null;
    }

    final dotWidget = Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: dotColor,
        shape: BoxShape.circle,
      ),
      child: icon != null
          ? Icon(icon, color: Colors.white, size: 14)
          : null,
    );

    final stepRow = Row(
      children: [
        if (status == _PipelineStatus.active)
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Opacity(
                  opacity: _opacityAnimation.value,
                  child: child,
                ),
              );
            },
            child: dotWidget,
          )
        else
          dotWidget,
        const SizedBox(width: AppSpacing.md),
        Text(label, style: AppTextStyles.body),
      ],
    );

    if (inlineContent != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          stepRow,
          inlineContent,
        ],
      );
    }

    return stepRow;
  }
}

enum _PipelineStatus { done, active, error, pending }
