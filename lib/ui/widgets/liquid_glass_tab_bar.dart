// Liquid Glass нижняя панель навигации (тема-aware).
// 3 таба: Главная · История · Настройки. Активный — оранжевая «пилюля».
//
// Цвета берёт из context.palette — переключается с темой автоматически.

import 'dart:ui';
import 'package:flutter/material.dart';

import '../../core/constants/design_tokens.dart';

class LiquidGlassTabBar extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onChanged;
  final List<TabItem> items;
  final EdgeInsets margin;

  const LiquidGlassTabBar({
    super.key,
    required this.activeIndex,
    required this.onChanged,
    this.items = const [
      TabItem(label: 'Главная', icon: TabIconKind.home),
      TabItem(label: 'История', icon: TabIconKind.doc),
      TabItem(label: 'Настройки', icon: TabIconKind.gear),
    ],
    this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 30),
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9999),
              color: palette.glassBg,
              border: Border.all(color: palette.glassRim, width: 0.5),
              boxShadow: [palette.shadow],
            ),
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: _TabPill(
                      item: items[i],
                      active: i == activeIndex,
                      onTap: () => onChanged(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TabItem {
  final String label;
  final TabIconKind icon;
  const TabItem({required this.label, required this.icon});
}

enum TabIconKind { home, doc, gear }

class _TabPill extends StatelessWidget {
  final TabItem item;
  final bool active;
  final VoidCallback onTap;

  const _TabPill({
    required this.item,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final inactiveColor = palette.ink2;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9999),
          color: active ? const Color(0xEBFF5B3A) : Colors.transparent,
          boxShadow: active
              ? const [
                  BoxShadow(
                    color: Color(0x57FF5B3A),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
          border: active
              ? const Border.fromBorderSide(
                  BorderSide(color: Color(0x73FFFFFF), width: 0.5))
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomPaint(
              size: const Size(22, 22),
              painter: _TabIconPainter(
                kind: item.icon,
                color: active ? Colors.white : inactiveColor,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                letterSpacing: -0.13,
                color: active ? Colors.white : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabIconPainter extends CustomPainter {
  final TabIconKind kind;
  final Color color;
  _TabIconPainter({required this.kind, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    canvas.scale(scale);

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (kind) {
      case TabIconKind.home:
        final p = Path()
          ..moveTo(3, 11.5)
          ..lineTo(12, 4)
          ..lineTo(21, 11.5)
          ..lineTo(21, 20)
          ..arcToPoint(const Offset(19.5, 21.5),
              radius: const Radius.circular(1.5))
          ..lineTo(15.5, 21.5)
          ..lineTo(15.5, 14)
          ..lineTo(8.5, 14)
          ..lineTo(8.5, 21.5)
          ..lineTo(4.5, 21.5)
          ..arcToPoint(const Offset(3, 20),
              radius: const Radius.circular(1.5))
          ..close();
        canvas.drawPath(p, stroke);

      case TabIconKind.doc:
        final body = Path()
          ..moveTo(6, 3)
          ..lineTo(14, 3)
          ..lineTo(19, 8)
          ..lineTo(19, 19)
          ..arcToPoint(const Offset(17, 21), radius: const Radius.circular(2))
          ..lineTo(7, 21)
          ..arcToPoint(const Offset(5, 19), radius: const Radius.circular(2))
          ..lineTo(5, 5)
          ..arcToPoint(const Offset(7, 3), radius: const Radius.circular(2))
          ..close();
        canvas.drawPath(body, stroke);
        canvas.drawPath(
          Path()
            ..moveTo(14, 3)
            ..lineTo(14, 8)
            ..lineTo(19, 8),
          stroke,
        );
        canvas.drawLine(const Offset(8, 13), const Offset(16, 13), stroke);
        canvas.drawLine(const Offset(8, 17), const Offset(14, 17), stroke);

      case TabIconKind.gear:
        canvas.drawCircle(const Offset(12, 12), 3, stroke);
        const spokes = [
          [12.0, 2.0, 12.0, 5.0],
          [12.0, 19.0, 12.0, 22.0],
          [22.0, 12.0, 19.0, 12.0],
          [5.0, 12.0, 2.0, 12.0],
          [19.0, 5.0, 17.0, 7.0],
          [7.0, 17.0, 5.0, 19.0],
          [19.0, 19.0, 17.0, 17.0],
          [7.0, 7.0, 5.0, 5.0],
        ];
        for (final s in spokes) {
          canvas.drawLine(Offset(s[0], s[1]), Offset(s[2], s[3]), stroke);
        }
    }
  }

  @override
  bool shouldRepaint(covariant _TabIconPainter old) =>
      old.kind != kind || old.color != color;
}
