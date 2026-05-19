import 'package:flutter/material.dart';

import '../../core/constants/design_tokens.dart';

/// Фон: gradient + 5 радиальных пятен. Цвета берёт из `context.palette`,
/// автоматически переключается light ↔ dark.
class GradientBackground extends StatelessWidget {
  const GradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: DecoratedBox(decoration: BoxDecoration(gradient: palette.bgGradient)),
        ),
        Positioned.fill(child: CustomPaint(painter: _WallpaperPainter(palette))),
        child,
      ],
    );
  }
}

class _WallpaperPainter extends CustomPainter {
  _WallpaperPainter(this.palette);

  final AppPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    for (final b in blobsOf(palette)) {
      _drawRadial(canvas, size,
          cx: b.cx, cy: b.cy, rx: b.rx, ry: b.ry,
          color: b.color, alpha: b.alpha);
    }
  }

  void _drawRadial(
    Canvas canvas,
    Size size, {
    required double cx,
    required double cy,
    required double rx,
    required double ry,
    required Color color,
    required double alpha,
  }) {
    final center = Offset(size.width * cx, size.height * cy);
    final radiusX = size.width * rx;
    final radiusY = size.height * ry;
    final radius = (radiusX + radiusY) / 2;

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0.0)],
        stops: const [0.0, 1.0],
      ).createShader(
        Rect.fromCenter(center: center, width: radiusX * 2, height: radiusY * 2),
      );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(1.0, radiusY / radius);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawCircle(center, radius, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WallpaperPainter old) => old.palette != palette;
}
