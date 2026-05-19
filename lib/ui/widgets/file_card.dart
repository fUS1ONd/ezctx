import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/design_tokens.dart';
import '../../features/transcription/audio_metadata.dart';
import '../../features/transcription/selected_audio_file.dart';
import 'glass_card.dart';
import 'primary_button.dart';

/// Карточка выбранного файла на Home: иконка, имя/мета, кнопка «Заменить»,
/// CTA «Транскрибировать» — всё внутри одной glass-карточки.
class FileCard extends StatelessWidget {
  const FileCard({
    super.key,
    required this.file,
    required this.metadata,
    required this.loadingMetadata,
    required this.onReplace,
    required this.onTranscribe,
  });

  final SelectedAudioFile file;
  final AudioMetadata? metadata;
  final bool loadingMetadata;
  final VoidCallback onReplace;
  final VoidCallback onTranscribe;

  String _metaLine() {
    if (metadata != null) {
      return '${metadata!.sizeFormatted} · ${metadata!.durationFormatted}';
    }
    return '${file.sizeFormatted} · ${file.extension.toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return GlassCard(
      borderRadius: 30,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Файл-строка ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.glassBgDeep,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: palette.glassRim, width: 0.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: AppGradients.accent,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.30),
                        blurRadius: 14,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.audiotrack,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.heading
                            .copyWith(color: palette.ink1, fontSize: 17),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _metaLine(),
                            style: AppTextStyles.mono
                                .copyWith(color: palette.ink2),
                          ),
                          if (loadingMetadata) ...[
                            const SizedBox(width: 8),
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 1.5),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: onReplace,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text(
                    'Заменить',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          // ── Декоративная волна ──
          const SizedBox(height: 12),
          const SizedBox(
            height: 56,
            child: CustomPaint(painter: _WaveformPainter(), size: Size.infinite),
          ),
          const SizedBox(height: 14),

          PrimaryButton(
            label: 'Транскрибировать',
            icon: Icons.graphic_eq,
            onPressed: onTranscribe,
          ),
        ],
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const bars = 48;
    final w = size.width / bars;
    final barW = w * 0.55;
    final gap = w - barW;

    for (var i = 0; i < bars; i++) {
      // псевдослучайно, но детерминированно
      final v = (math.sin(i * 1.7) * math.cos(i * 0.6 + 1.1))
          .abs()
          .clamp(0.16, 1.0);
      final h = v * size.height;
      final x = i * w + gap / 2;
      final y = (size.height - h) / 2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barW, h),
        const Radius.circular(2),
      );
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.accentGradientStart.withValues(alpha: 0.55 + v * 0.40),
            AppColors.accent.withValues(alpha: 0.35 + v * 0.40),
          ],
        ).createShader(rect.outerRect);
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
