import 'package:flutter/material.dart';

/// Цветовая палитра приложения из UI-SPEC / design/styles.css.
class AppColors {
  AppColors._();

  // Акцент (CTA, иконка, shimmer)
  static const Color accent = Color(0xFFFF5B3A);
  static const Color accentGradientStart = Color(0xFFFF8A4D);

  // Статусы
  static const Color good = Color(0xFF2DB585);
  static const Color bad = Color(0xFFE0395A);

  // Текст
  static const Color inkPrimary = Color(0xFF1A1421);
  static const Color inkSecondary = Color(0x9E1A1421); // 0.62 opacity
  static const Color inkTertiary = Color(0x611A1421); // 0.38 opacity
  static const Color inkDivider = Color(0x141A1421); // 0.08 opacity

  // Glass поверхности
  static const Color glassSurface = Color(0x7AFFFFFF); // 0.48 opacity
  static const Color glassDeep = Color(0xA8FFFFFF); // 0.66 opacity
}

/// Радиусы скругления из UI-SPEC.
class AppRadius {
  AppRadius._();

  static const double card = 22.0; // r-card
  static const double row = 16.0; // r-row
  static const double tile = 30.0; // r-tile
  static const double pill = 999.0; // r-pill
  static const double icon = 14.0; // r-icon (среднее значение)
}

/// Шкала отступов из UI-SPEC (кратно 4).
class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  static const double xxxl = 64.0;
}

/// Стили текста из UI-SPEC.
/// Ровно 4 фиксированных размера и 2 веса (400/700).
class AppTextStyles {
  AppTextStyles._();

  // Display: 34px, w700, letterSpacing -0.035em
  static const TextStyle display = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.2, // -0.035em × 34px ≈ -1.19
    color: AppColors.inkPrimary,
    height: 1.08,
  );

  // Heading: 20px, w700
  static const TextStyle heading = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.inkPrimary,
    height: 1.2,
  );

  // Body: 16px, w400
  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.16, // -0.01em × 16px
    color: AppColors.inkPrimary,
    height: 1.5,
  );

  // Label/Meta: 13px, w400
  static const TextStyle label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.inkSecondary,
    height: 1.3,
  );

  // Mono: для метаданных, таймкодов
  static const TextStyle mono = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    fontFamily: 'RobotoMono',
    color: AppColors.inkSecondary,
  );
}

/// Градиенты из UI-SPEC.
class AppGradients {
  AppGradients._();

  /// Градиент акцента (CTA, иконки).
  static const LinearGradient accent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.accentGradientStart, AppColors.accent],
  );

  /// Фон экрана: базовый линейный градиент.
  /// Полный фон реализуется в GradientBackground через CustomPainter (5 radial + 1 linear).
  static const LinearGradient backgroundBase = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFF3EA), Color(0xFFF3ECFF)],
  );
}
