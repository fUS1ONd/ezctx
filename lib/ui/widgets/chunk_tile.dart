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
    final palette = context.palette;
    final (color, icon, statusText) = _resolveVisuals(palette);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: palette.glassBgFlat,
        borderRadius: BorderRadius.circular(AppRadius.row),
        border: Border.all(color: palette.inkLine),
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
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700, color: palette.ink1),
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
  (Color, IconData, String) _resolveVisuals(AppPalette palette) {
    return switch (state) {
      ChunkWaiting() => (
          palette.ink3,
          Icons.hourglass_empty,
          'Ожидает',
        ),
      ChunkUploading() => (
          palette.accent,
          Icons.upload, // иконка не используется, но нужна для паттерна
          'Отправляется...',
        ),
      ChunkDone() => (
          palette.good,
          Icons.check_circle_outline,
          'Готов',
        ),
      ChunkRetrying(:final attempt, :final maxAttempts) => (
          palette.bad, // warn — используем bad как наиболее близкий к warn
          Icons.refresh,
          'Повтор $attempt/$maxAttempts',
        ),
      ChunkFailed(:final error) => (
          palette.bad,
          Icons.error_outline,
          'Ошибка: $error',
        ),
      // Все ключи временно заблокированы — ожидаем разблокировки пула.
      ChunkWaitingForKey() => (
          palette.ink3,
          Icons.key_off,
          'Ожидание ключа...',
        ),
    };
  }
}
