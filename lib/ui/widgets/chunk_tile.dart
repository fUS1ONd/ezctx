import 'package:flutter/material.dart';

import '../../core/constants/design_tokens.dart';
import '../../features/transcription/chunk_state.dart';

/// Плитка одного чанка в chunked-режиме ProcessingScreen.
///
/// Визуально различает 5 состояний: ожидает / отправляется / готов / ретрай / ошибка.
class ChunkTile extends StatelessWidget {
  final ChunkState state;

  const ChunkTile({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final (color, icon, statusText) = _resolveVisuals();

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.glassSurface,
        borderRadius: BorderRadius.circular(AppRadius.row),
        border: Border.all(color: AppColors.inkDivider),
      ),
      child: Row(
        children: [
          // Иконка состояния: для ChunkUploading — индикатор загрузки.
          if (state is ChunkUploading)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: color,
              ),
            )
          else
            Icon(icon, color: color, size: 20),

          const SizedBox(width: AppSpacing.sm),

          // Номер чанка
          Text(
            'Чанк ${state.index + 1}',
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
          ),

          const SizedBox(width: AppSpacing.sm),

          // Статусная надпись
          Expanded(
            child: Text(
              statusText,
              style: AppTextStyles.label.copyWith(color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Возвращает (цвет, иконку, текст статуса) по типу [state].
  (Color, IconData, String) _resolveVisuals() {
    return switch (state) {
      ChunkWaiting() => (
          AppColors.inkTertiary,
          Icons.hourglass_empty,
          'Ожидает',
        ),
      ChunkUploading() => (
          AppColors.accent,
          Icons.upload, // иконка не используется, но нужна для паттерна
          'Отправляется...',
        ),
      ChunkDone() => (
          AppColors.good,
          Icons.check_circle_outline,
          'Готов',
        ),
      ChunkRetrying(:final attempt) => (
          AppColors.bad, // warn — используем bad как наиболее близкий к warn
          Icons.refresh,
          'Повтор $attempt/3',
        ),
      ChunkFailed(:final error) => (
          AppColors.bad,
          Icons.error_outline,
          'Ошибка: $error',
        ),
    };
  }
}
