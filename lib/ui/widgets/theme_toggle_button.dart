import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/theme_provider.dart';
import 'glass_card.dart';

/// Круглая стеклянная кнопка-переключатель темы.
/// Иконка показывает текущее состояние (солнце = светлая, луна = тёмная).
/// На клик: light → dark → light. Режим `system` принудительно сбрасывается
/// в явный — пользователь после первого тапа всегда видит детерминированный
/// результат.
///
/// При смене темы иконка плавно поворачивается + меняет масштаб.
class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    final isDark = switch (mode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system => platformBrightness == Brightness.dark,
    };

    final iconColor = Theme.of(context).colorScheme.onSurface;

    return Semantics(
      label: isDark ? 'Переключить на светлую тему' : 'Переключить на тёмную тему',
      button: true,
      child: SizedBox(
        width: 44,
        height: 44,
        child: GestureDetector(
          onTap: () => ref.read(themeModeProvider.notifier).setTheme(
                isDark ? ThemeMode.light : ThemeMode.dark,
              ),
          child: Center(
            child: GlassCard(
              borderRadius: 22,
              padding: EdgeInsets.zero,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (child, anim) {
                      // Поворот + scale при кросс-фейде.
                      return RotationTransition(
                        turns: Tween<double>(begin: 0.25, end: 0.0).animate(anim),
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.7, end: 1.0).animate(anim),
                          child: FadeTransition(opacity: anim, child: child),
                        ),
                      );
                    },
                    child: Icon(
                      isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                      key: ValueKey(isDark),
                      size: 20,
                      color: iconColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
