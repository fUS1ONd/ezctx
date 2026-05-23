import 'package:flutter/material.dart';

import '../../core/constants/design_tokens.dart';
import '../../features/transcription/chunked_transcription_controller.dart';
import 'chunk_tile.dart';
import 'shimmer_bar.dart';

/// Inline-секция прогресса для chunked-режима.
/// Показывается внутри шага «Распознавание» в PipelineStepTile.
class ChunkedProgressSection extends StatelessWidget {
  const ChunkedProgressSection({super.key, required this.state});

  final ChunkedState state;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
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
                style: AppTextStyles.body.copyWith(color: palette.ink2),
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
                  backgroundColor: palette.inkLine,
                  color: palette.accent,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '$completedCount из $totalCount чанков',
                style: AppTextStyles.label.copyWith(color: palette.ink2),
              ),
              const SizedBox(height: AppSpacing.sm),
              ExpansionTile(
                title: Text('Детали чанков', style: AppTextStyles.label.copyWith(color: palette.ink2)),
                initiallyExpanded: true,
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                children: [
                  Column(
                    children: [
                      for (final c in chunks) ChunkTile(state: c),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

      _ => const SizedBox.shrink(),
    };
  }
}
