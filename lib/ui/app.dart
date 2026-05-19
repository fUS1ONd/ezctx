import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/constants/design_tokens.dart';
import 'screens/api_keys_screen.dart';
import 'screens/home_screen.dart';
import 'screens/processing_screen.dart';
import 'screens/result_screen.dart';
import 'screens/settings_screen.dart';

/// Корневой виджет приложения. Регистрирует именованные маршруты и тему.
class EzCtxApp extends StatelessWidget {
  const EzCtxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ezctx',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.transparent,
        textTheme: const TextTheme(
          displayLarge: AppTextStyles.display,
          titleLarge: AppTextStyles.heading,
          bodyLarge: AppTextStyles.body,
          labelSmall: AppTextStyles.label,
        ),
      ),
      initialRoute: AppConstants.routeHome,
      // Fade-переходы 300 мс easeInOut между всеми именованными маршрутами
      onGenerateRoute: (settings) {
        Widget page;
        switch (settings.name) {
          case AppConstants.routeHome:
            page = const HomeScreen();
          case AppConstants.routeSettings:
            page = const SettingsScreen();
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
}
