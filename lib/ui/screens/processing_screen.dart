import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/design_tokens.dart';
import '../../core/storage/secure_storage_service.dart';
import '../../features/settings/api_key_repository.dart';
import '../../features/transcription/groq_api_service.dart';
import '../../features/transcription/result_args.dart';
import '../../features/transcription/selected_audio_file.dart';
import '../../features/transcription/transcription_controller.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_icon_btn.dart';
import '../widgets/gradient_background.dart';
import '../widgets/primary_button.dart';
import '../widgets/shimmer_bar.dart';

/// Экран обработки: запускает транскрибацию, показывает pipeline, обрабатывает ошибки.
class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({super.key});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  late final TranscriptionController _controller;
  SelectedAudioFile? _file;
  DateTime? _startedAt;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _controller = TranscriptionController(
      keyRepository: ApiKeyRepository(SecureStorageServiceImpl()),
      apiService: GroqApiService(),
    );
    _controller.addListener(_onStateChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_file == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is SelectedAudioFile) {
        _file = args;
        _startedAt = DateTime.now();
        _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) {
            setState(() => _elapsed = DateTime.now().difference(_startedAt!));
          }
        });
        _controller.start(_file!);
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
        });
      }
    }
  }

  void _onStateChange() {
    final s = _controller.state;
    if (s is TranscriptionSuccess) {
      _ticker?.cancel();
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          AppConstants.routeResult,
          arguments: ResultArgs(file: _file!, result: s.result),
        );
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _controller.removeListener(_onStateChange);
    _controller.dispose();
    super.dispose();
  }

  String _formatElapsed(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    final isLoading = state is TranscriptionLoading;
    final isError = state is TranscriptionError;
    final isMissingKey = state is TranscriptionMissingKey;

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
                if (_file != null)
                  GlassCard(
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

                // ShimmerBar — виден только при загрузке
                if (isLoading) ...[
                  const ShimmerBar(),
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
                        label: 'Распознавание',
                        status: isError
                            ? _PipelineStatus.error
                            : isLoading
                                ? _PipelineStatus.active
                                : isMissingKey
                                    ? _PipelineStatus.pending
                                    : _PipelineStatus.done,
                      ),
                      const Divider(height: AppSpacing.lg),
                      _buildPipelineStep(
                        label: 'Готово',
                        status: _PipelineStatus.pending,
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Нижняя панель: loading / error / missingKey
                _buildBottomBar(state),

                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
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

    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
          child: icon != null
              ? Icon(icon, color: Colors.white, size: 14)
              : null,
        ),
        const SizedBox(width: AppSpacing.md),
        Text(label, style: AppTextStyles.body),
      ],
    );
  }

  Widget _buildBottomBar(TranscriptionState state) {
    if (state is TranscriptionLoading) {
      return Column(
        children: [
          Text(_formatElapsed(_elapsed), style: AppTextStyles.mono),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
            child: Text(
              'Отменить обработку',
              style: AppTextStyles.label.copyWith(color: AppColors.bad),
            ),
          ),
        ],
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
              onPressed: () => _controller.start(_file!),
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
