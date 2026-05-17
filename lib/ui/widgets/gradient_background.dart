import 'package:flutter/material.dart';

/// Фон приложения: 5 радиальных градиентов поверх базового линейного.
/// Реализует «Wallpaper / Background» из UI-SPEC.
class GradientBackground extends StatelessWidget {
  const GradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Базовый линейный градиент (нижний слой)
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFF3EA), Color(0xFFF3ECFF)],
              ),
            ),
          ),
        ),
        // 5 радиальных градиентов (поверх линейного)
        Positioned.fill(child: CustomPaint(painter: _WallpaperPainter())),
        // Контент поверх фона
        child,
      ],
    );
  }
}

class _WallpaperPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // radial-gradient(60% 45% at 18% 8%, #ffd2b8 → transparent)
    _drawRadial(
      canvas,
      size,
      cx: 0.18,
      cy: 0.08,
      rx: 0.6,
      ry: 0.45,
      color: const Color(0xFFFFD2B8),
    );
    // radial-gradient(55% 40% at 92% 22%, #f9c4dd → transparent)
    _drawRadial(
      canvas,
      size,
      cx: 0.92,
      cy: 0.22,
      rx: 0.55,
      ry: 0.40,
      color: const Color(0xFFF9C4DD),
    );
    // radial-gradient(75% 55% at 50% 95%, #c9bfff → transparent)
    _drawRadial(
      canvas,
      size,
      cx: 0.50,
      cy: 0.95,
      rx: 0.75,
      ry: 0.55,
      color: const Color(0xFFC9BFFF),
    );
    // radial-gradient(45% 35% at 85% 78%, #ffb39a → transparent)
    _drawRadial(
      canvas,
      size,
      cx: 0.85,
      cy: 0.78,
      rx: 0.45,
      ry: 0.35,
      color: const Color(0xFFFFB39A),
    );
    // radial-gradient(40% 30% at 8% 60%, #ffe7a8 → transparent)
    _drawRadial(
      canvas,
      size,
      cx: 0.08,
      cy: 0.60,
      rx: 0.40,
      ry: 0.30,
      color: const Color(0xFFFFE7A8),
    );
  }

  void _drawRadial(
    Canvas canvas,
    Size size, {
    required double cx,
    required double cy,
    required double rx,
    required double ry,
    required Color color,
  }) {
    final center = Offset(size.width * cx, size.height * cy);
    final radiusX = size.width * rx;
    final radiusY = size.height * ry;
    final radius = (radiusX + radiusY) / 2;

    final paint =
        Paint()
          ..shader = RadialGradient(
            colors: [color.withValues(alpha: 0.7), color.withValues(alpha: 0.0)],
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
  bool shouldRepaint(_WallpaperPainter oldDelegate) => false;
}
