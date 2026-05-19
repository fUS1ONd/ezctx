import 'package:flutter/material.dart';

import '../../core/constants/design_tokens.dart';

/// Анимированный shimmer-bar прогресса.
/// Цикл 1600ms (UI-SPEC Animations: shimmer 1.6s linear).
class ShimmerBar extends StatefulWidget {
  const ShimmerBar({super.key});

  @override
  State<ShimmerBar> createState() => _ShimmerBarState();
}

class _ShimmerBarState extends State<ShimmerBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _animation = CurvedAnimation(parent: _controller, curve: Curves.linear);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: SizedBox(
            height: 6,
            child: Stack(
              children: [
                // Фоновая полоса
                Container(
                  decoration: BoxDecoration(
                    color: palette.glassBgDeep,
                  ),
                ),
                // Движущийся яркий сегмент
                FractionallySizedBox(
                  widthFactor: 0.35,
                  child: Transform.translate(
                    offset: Offset(
                      (_animation.value * 2 - 0.35) *
                          MediaQuery.sizeOf(context).width,
                      0,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            palette.accent.withValues(alpha: 0.18),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
