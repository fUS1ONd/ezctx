import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/constants/design_tokens.dart';
import 'screens/api_keys_screen.dart';
import 'screens/processing_screen.dart';
import 'screens/result_screen.dart';
import 'widgets/scaffold_with_nav_bar.dart';

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
      // ScaffoldWithNavBar — корневой shell с тремя вкладками (IndexedStack).
      // ProcessingScreen и ResultScreen пушатся поверх через Navigator.push.
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
}
