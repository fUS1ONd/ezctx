import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/constants/design_tokens.dart';
import '../core/providers/theme_provider.dart';
import 'screens/api_keys_screen.dart';
import 'screens/processing_screen.dart';
import 'screens/result_screen.dart';
import 'widgets/scaffold_with_nav_bar.dart';

/// Корневой виджет приложения. Регистрирует именованные маршруты и тему.
class EzCtxApp extends ConsumerWidget {
  const EzCtxApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'ezctx',
      debugShowCheckedModeBanner: false,
      showPerformanceOverlay: true, // ВРЕМЕННО для замера scroll jank — удалить перед merge
      themeMode: themeMode,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: const ScaffoldWithNavBar(),
      onGenerateRoute: (settings) {
        Widget page;
        switch (settings.name) {
          case AppConstants.routeApiKeys:
            page = const ApiKeysScreen();
          case AppConstants.routeProcessing:
            page = const ProcessingScreen();
          case AppConstants.routeResult:
            page = const ResultScreen();
          default:
            return null;
        }
        return PageRouteBuilder(
          settings: settings,
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (ctx, animation, secondaryAnimation) => page,
          transitionsBuilder: (ctx, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOut,
              ),
              child: child,
            );
          },
        );
      },
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final palette = brightness == Brightness.dark
        ? AppPalette.dark
        : AppPalette.light;

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: ColorScheme.fromSeed(
        seedColor: palette.accent,
        brightness: brightness,
      ).copyWith(
        surface: brightness == Brightness.dark
            ? const Color(0xFF16111F)
            : const Color(0xFFFFF3EA),
        onSurface: palette.ink1,
      ),
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displayLarge: AppTextStyles.display.copyWith(color: palette.ink1),
        titleLarge: AppTextStyles.heading.copyWith(color: palette.ink1),
        bodyLarge: AppTextStyles.body.copyWith(color: palette.ink1),
        labelSmall: AppTextStyles.label.copyWith(color: palette.ink2),
      ),
    );
  }
}
