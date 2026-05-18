import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/design_tokens.dart';
import '../../features/transcription/audio_chunking_service.dart';
import '../../features/transcription/audio_normalization_service.dart';
import '../../features/transcription/chunked_transcription_controller.dart';
import '../../features/transcription/groq_api_service.dart';
import '../../features/transcription/groq_key_pool.dart';
import '../../features/transcription/normalized_audio_file.dart';
import '../../features/transcription/processing_args.dart';
import '../../features/transcription/result_args.dart';
import '../../features/transcription/selected_audio_file.dart';
import '../../features/transcription/transcription_controller.dart';
import '../../features/transcription/transcription_options.dart';
import '../widgets/chunk_tile.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_icon_btn.dart';
import '../widgets/glass_tile.dart';
import '../widgets/gradient_background.dart';
import '../widgets/primary_button.dart';
import '../widgets/shimmer_bar.dart';

/// Экран обработки: запускает транскрибацию, показывает pipeline, обрабатывает ошибки.
/// Принимает [groqKeyPool] — singleton пул ключей из main.dart.
class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({super.key, required this.groqKeyPool});

  /// Singleton пул Groq API-ключей, передаётся в контроллеры транскрибации.
  final GroqKeyPool groqKeyPool;

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen>
    with SingleTickerProviderStateMixin {
  late final TranscriptionController _controller;

  /// Контроллер для chunked-режима (большие файлы ≥ 19 МБ).
  ChunkedTranscriptionController? _chunkedController;

  /// true — длительность нормализованного mp3 > kChunkThresholdSeconds.
  bool _isChunked = false;

  /// true — идёт нормализация аудио.
  bool _normalizing = false;

  /// Результат нормализации (нормализованный временный файл).
  NormalizedAudioFile? _normalizedFile;

  /// Ошибка нормализации.
  String? _normalizationError;

  /// Настройки транскрибации, переданные с HomeScreen через ProcessingArgs.
  TranscriptionOptions _transcriptionOptions = const TranscriptionOptions.defaults();

  SelectedAudioFile? _file;
  DateTime? _startedAt;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;

  /// Контроллер для пульс-анимации активной точки pipeline.
  late final AnimationController _pulseController;

  /// Анимация масштаба: 1.0 → 1.25.
  late final Animation<double> _scaleAnimation;

  /// Анимация прозрачности: 0.6 → 1.0.
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    // Используем pool из widget — singleton создан в main.dart.
    _controller = TranscriptionController(
      pool: widget.groqKeyPool,
      apiService: GroqApiService(),
    );
    _controller.addListener(_onStateChange);

    // Инициализация пульс-анимации активной точки pipeline (1200 мс, зацикленная).
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
        // Обратная совместимость — старый путь без ProcessingArgs.
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

        // Запускаем pipeline через postFrameCallback, чтобы контекст был готов.
        WidgetsBinding.instance.addPostFrameCallback((_) => _startProcessing());
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
        });
      }
    }
  }

  /// Основной pipeline: нормализация → (chunked | single) транскрибация.
  Future<void> _startProcessing() async {
    if (!mounted) return;
    setState(() {
      _normalizing = true;
      _normalizationError = null;
    });

    try {
      _normalizedFile = await AudioNormalizationService().normalize(_file!.path);
      _isChunked =
          _normalizedFile!.durationSeconds > AppConstants.kChunkThresholdSeconds;
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

    if (_isChunked) {
      // Chunked-режим: создаём ChunkedTranscriptionController с pool из widget.
      _chunkedController = ChunkedTranscriptionController(
        pool: widget.groqKeyPool,
        apiService: GroqApiService(),
        chunkingService: AudioChunkingService(),
      );
      _chunkedController!.addListener(_onChunkedStateChange);
      // await: некропотанные исключения внутри start() долетят до try/catch
      // этого метода, а не будут молча проглочены как unhandled Future rejection.
      await _chunkedController!.start(_normalizedFile!, options: _transcriptionOptions);
    } else {
      // Стандартный режим: TranscriptionController с нормализованным файлом.
      final normalizedAudioFile = SelectedAudioFile(
        path: _normalizedFile!.path,
        name: _file!.name,
        sizeBytes: File(_normalizedFile!.path).statSync().size,
        extension: 'mp3',
      );
      await _controller.start(normalizedAudioFile, options: _transcriptionOptions);
    }
  }

  /// Callback при изменении состояния ChunkedTranscriptionController.
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
      // return: предотвращаем повторный setState ниже для пути ChunkedSuccess.
      return;
    }
    if (mounted) setState(() {});
  }

  void _onStateChange() {
    final s = _controller.state;
    if (s is TranscriptionSuccess) {
      _ticker?.cancel();
      if (mounted) {
        // Показываем "Готово" (done) на 300 мс, затем переходим на экран результата.
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
    }
    if (mounted) setState(() {});
  }

  /// Перезапускает таймер и pipeline при повторной попытке.
  void _restart() {
    _ticker?.cancel();
    setState(() {
      _elapsed = Duration.zero;
      _startedAt = DateTime.now();
      _normalizationError = null;
      _normalizedFile = null;
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
    _controller.removeListener(_onStateChange);
    _controller.dispose();
    _chunkedController?.removeListener(_onChunkedStateChange);
    _chunkedController?.dispose();
    // Удаляем временный нормализованный файл.
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
    // Chunked-режим: показываем отдельный экран прогресса по чанкам.
    if (_isChunked && _chunkedController != null) {
      return _buildChunkedScaffold(_chunkedController!.state);
    }

    // Стандартный режим (Phase 1 путь).
    final state = _controller.state;
    final isLoading = _normalizing || state is TranscriptionLoading;
    final isError = !_normalizing && state is TranscriptionError;
    final isMissingKey = !_normalizing && state is TranscriptionMissingKey;

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

                // Карточка файла: GlassTile (r=30px) вместо GlassCard (r=22px)
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

                // ShimmerBar — виден при нормализации или загрузке
                if (isLoading) ...[
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

                // Pipeline
                GlassCard(
                  child: Column(
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
                        status: isError
                            ? _PipelineStatus.error
                            : (state is TranscriptionLoading
                                ? _PipelineStatus.active
                                : isMissingKey
                                    ? _PipelineStatus.pending
                                    : (state is TranscriptionSuccess
                                        ? _PipelineStatus.done
                                        : _PipelineStatus.pending)),
                      ),
                      const Divider(height: AppSpacing.lg),
                      _buildPipelineStep(
                        label: 'Готово',
                        // Отображаем done только при успешном завершении.
                        status: state is TranscriptionSuccess
                            ? _PipelineStatus.done
                            : _PipelineStatus.pending,
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Ошибка нормализации
                if (_normalizationError != null)
                  _buildNormalizationError(_normalizationError!),

                // Нижняя панель: loading / error / missingKey
                if (_normalizationError == null) _buildBottomBar(state),

                // Безопасный нижний отступ с учётом системной панели навигации
                SizedBox(height: MediaQuery.of(context).padding.bottom + 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Панель ошибки нормализации с кнопкой «Повторить».
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

  // ---------------------------------------------------------------------------
  // Chunked-режим UI
  // ---------------------------------------------------------------------------

  /// Scaffold для chunked-режима (файл ≥ 19 МБ).
  Widget _buildChunkedScaffold(ChunkedState state) {
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

                // Карточка файла
                if (_file != null) _buildFileCard(_file!),

                const SizedBox(height: AppSpacing.lg),

                // Тело по состоянию chunked-контроллера
                Expanded(child: _buildChunkedBody(state)),

                // Безопасный нижний отступ
                SizedBox(height: MediaQuery.of(context).padding.bottom + 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Карточка файла (общая для chunked и single режима).
  Widget _buildFileCard(SelectedAudioFile file) {
    return GlassTile(
      child: Row(
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
                Text(
                  '${file.sizeFormatted} · ${file.extension.toUpperCase()}',
                  style: AppTextStyles.label,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Тело chunked-экрана в зависимости от [state].
  Widget _buildChunkedBody(ChunkedState state) {
    return switch (state) {
      ChunkedIdle() => const SizedBox.shrink(),

      ChunkedSplitting() => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ShimmerBar(),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Разбиваем на чанки...',
              style: AppTextStyles.body.copyWith(color: AppColors.inkSecondary),
            ),
          ],
        ),

      ChunkedProcessing(:final chunks, :final completedCount, :final totalCount) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Прогресс-бар
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
              '$completedCount из $totalCount чанков готово',
              style: AppTextStyles.label,
            ),
            const SizedBox(height: AppSpacing.md),
            // Список плиток чанков — shrinkWrap, т.к. Column уже внутри Expanded
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: chunks.length,
              itemBuilder: (context, i) => ChunkTile(state: chunks[i]),
            ),
          ],
        ),

      ChunkedSuccess() => const SizedBox.shrink(), // навигация выполняется в _onChunkedStateChange

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
    };
  }

  Widget _buildPipelineStep({
    required String label,
    required _PipelineStatus status,
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

    // Активная точка получает пульс-анимацию масштаба и прозрачности.
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

    return Row(
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
  }

  Widget _buildBottomBar(TranscriptionState state) {
    if (state is TranscriptionLoading) {
      // Floating glass pill с таймером и кнопкой отмены
      return GlassCard(
        borderRadius: AppRadius.pill,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Elapsed time в формате mm:ss
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
      );
    }

    if (state is TranscriptionError) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            state.message,
            style: AppTextStyles.label.copyWith(color: AppColors.bad),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (state.retryable && _file != null)
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

    if (state is TranscriptionMissingKey) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Сначала добавьте API-ключ в настройках',
            style: AppTextStyles.label.copyWith(color: AppColors.bad),
          ),
          const SizedBox(height: AppSpacing.sm),
          PrimaryButton(
            label: 'Перейти в настройки',
            onPressed: () =>
                Navigator.pushNamed(context, AppConstants.routeApiKeys),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}

enum _PipelineStatus { done, active, error, pending }
