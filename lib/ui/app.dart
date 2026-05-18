import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/constants/design_tokens.dart';
import '../features/transcription/groq_key_pool.dart';
import 'screens/api_keys_screen.dart';
import 'screens/home_screen.dart';
import 'screens/processing_screen.dart';
import 'screens/result_screen.dart';
import 'screens/settings_screen.dart';

/// Корневой виджет приложения. Регистрирует именованные маршруты и тему.
/// Принимает [groqKeyPool] — singleton пул ключей, созданный в main.dart.
class EzCtxApp extends StatelessWidget {
  const EzCtxApp({super.key, required this.groqKeyPool});

  /// Singleton пул Groq API-ключей, передаётся в контроллеры транскрибации.
  final GroqKeyPool groqKeyPool;

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
            // Pool передаётся заранее; ApiKeysScreen использует его в плане 04-03.
            page = const ApiKeysScreen();
          case AppConstants.routeProcessing:
            // Pool передаётся в ProcessingScreen для инициализации контроллеров.
            page = ProcessingScreen(groqKeyPool: groqKeyPool);
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
