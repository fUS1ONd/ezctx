import 'package:flutter/material.dart';

// ─── AppPalette ────────────────────────────────────────────
// Темо-зависимая палитра. `AppColors` ниже сохранён как набор
// светлых const-значений — это сохраняет обратную совместимость
// со старым кодом (тесты, ProcessingScreen, ResultScreen).
//
// Новый код должен брать цвета через расширение `context.palette`,
// тогда они автоматически переключатся в тёмную тему.

class AppPalette {
  const AppPalette({
    required this.accent,
    required this.accent2,
    required this.good,
    required this.bad,
    required this.ink1,
    required this.ink2,
    required this.ink3,
    required this.inkLine,
    required this.glassBg,
    required this.glassBgDeep,
    required this.glassRim,
    required this.bgGradient,
    required this.blobs,
    required this.shadow,
    required this.shadowDeep,
  });

  // Бренд (общие для обеих тем)
  final Color accent;
  final Color accent2;
  final Color good;
  final Color bad;

  // Текст
  final Color ink1;     // primary
  final Color ink2;     // secondary
  final Color ink3;     // tertiary / disabled
  final Color inkLine;  // divider

  // Стекло
  final Color glassBg;
  final Color glassBgDeep;
  final Color glassRim;

  // Обои
  final Gradient bgGradient;
  final List<_Blob> blobs;

  // Тени
  final BoxShadow shadow;
  final BoxShadow shadowDeep;

  // ── Light ──
  static const light = AppPalette(
    accent: Color(0xFFFF5B3A),
    accent2: Color(0xFFFF8A4D),
    good: Color(0xFF2DB585),
    bad: Color(0xFFE0395A),
    ink1: Color(0xFF1A1421),
    ink2: Color(0x9E1A1421),
    ink3: Color(0x611A1421),
    inkLine: Color(0x141A1421),
    glassBg: Color(0x7AFFFFFF),       // .48
    glassBgDeep: Color(0xA8FFFFFF),   // .66
    glassRim: Color(0xD9FFFFFF),
    bgGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFFFF3EA), Color(0xFFF3ECFF)],
    ),
    blobs: [
      _Blob(cx: 0.18, cy: 0.08, rx: 0.60, ry: 0.45, color: Color(0xFFFFD2B8), alpha: 0.70),
      _Blob(cx: 0.92, cy: 0.22, rx: 0.55, ry: 0.40, color: Color(0xFFF9C4DD), alpha: 0.65),
      _Blob(cx: 0.50, cy: 0.95, rx: 0.75, ry: 0.55, color: Color(0xFFC9BFFF), alpha: 0.70),
      _Blob(cx: 0.85, cy: 0.78, rx: 0.45, ry: 0.35, color: Color(0xFFFFB39A), alpha: 0.60),
      _Blob(cx: 0.08, cy: 0.60, rx: 0.40, ry: 0.30, color: Color(0xFFFFE7A8), alpha: 0.60),
    ],
    shadow: BoxShadow(
      color: Color(0x1A140A1E),
      blurRadius: 24,
      offset: Offset(0, 10),
    ),
    shadowDeep: BoxShadow(
      color: Color(0x33140A1E),
      blurRadius: 40,
      offset: Offset(0, 18),
    ),
  );

  // ── Dark ──
  static const dark = AppPalette(
    accent: Color(0xFFFF5B3A),
    accent2: Color(0xFFFF8A4D),
    good: Color(0xFF2DB585),
    bad: Color(0xFFE0395A),
    ink1: Color(0xFFF4EEFA),
    ink2: Color(0xA8F4EEFA),
    ink3: Color(0x66F4EEFA),
    inkLine: Color(0x1AF4EEFA),
    glassBg: Color(0x0FFFFFFF),       // .06
    glassBgDeep: Color(0x1AFFFFFF),   // .10
    glassRim: Color(0x24FFFFFF),      // .14
    bgGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF16111F), Color(0xFF1E1730)],
    ),
    blobs: [
      _Blob(cx: 0.18, cy: 0.08, rx: 0.60, ry: 0.45, color: Color(0xFFFF7A46), alpha: 0.32),
      _Blob(cx: 0.92, cy: 0.22, rx: 0.55, ry: 0.40, color: Color(0xFFD663A9), alpha: 0.30),
      _Blob(cx: 0.50, cy: 0.95, rx: 0.75, ry: 0.55, color: Color(0xFF6E58DC), alpha: 0.45),
      _Blob(cx: 0.85, cy: 0.78, rx: 0.45, ry: 0.35, color: Color(0xFFFF7A5C), alpha: 0.24),
      _Blob(cx: 0.08, cy: 0.60, rx: 0.40, ry: 0.30, color: Color(0xFFFFBE6E), alpha: 0.16),
    ],
    shadow: BoxShadow(
      color: Color(0x73000000),
      blurRadius: 30,
      offset: Offset(0, 10),
    ),
    shadowDeep: BoxShadow(
      color: Color(0x8C000000),
      blurRadius: 50,
      offset: Offset(0, 22),
    ),
  );
}

class _Blob {
  const _Blob({
    required this.cx,
    required this.cy,
    required this.rx,
    required this.ry,
    required this.color,
    required this.alpha,
  });
  final double cx, cy, rx, ry, alpha;
  final Color color;
}

extension AppPaletteX on BuildContext {
  AppPalette get palette =>
      Theme.of(this).brightness == Brightness.dark
          ? AppPalette.dark
          : AppPalette.light;
}

extension BlobAccess on AppPalette {
  Iterable<_Blob> get blobList => blobs;
}

// Доступ к приватному полю _Blob для CustomPainter обоев.
class BlobView {
  BlobView(_Blob b)
      : cx = b.cx, cy = b.cy, rx = b.rx, ry = b.ry,
        color = b.color, alpha = b.alpha;
  final double cx, cy, rx, ry, alpha;
  final Color color;
}

List<BlobView> blobsOf(AppPalette p) =>
    p.blobs.map(BlobView.new).toList(growable: false);

// ─── Брендовые константы ──────────────────────────────────
// Только акцент и статусные цвета — одинаковые в обеих темах.
// Не использовать в новом коде вне Widget-дерева; в виджетах — context.palette.
class AppColors {
  AppColors._();

  static const Color accent = Color(0xFFFF5B3A);
  static const Color accentGradientStart = Color(0xFFFF8A4D);

  static const Color good = Color(0xFF2DB585);
  static const Color bad = Color(0xFFE0395A);
}

class AppRadius {
  AppRadius._();
  static const double card = 22.0;
  static const double row = 16.0;
  static const double tile = 30.0;
  static const double pill = 999.0;
  static const double icon = 14.0;
}

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

class AppTextStyles {
  AppTextStyles._();

  // Базовые цвета — fallback для light-темы. В виджетах всегда copyWith(color: palette.inkX).
  static const _ink1 = Color(0xFF1A1421);
  static const _ink2 = Color(0x9E1A1421);
  static const _ink3 = Color(0x611A1421);

  static const TextStyle display = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.2,
    color: _ink1,
    height: 1.08,
  );

  static const TextStyle heading = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: _ink1,
    height: 1.2,
  );

  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.16,
    color: _ink1,
    height: 1.5,
  );

  static const TextStyle label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: _ink2,
    height: 1.3,
  );

  static const TextStyle mono = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    fontFamily: 'RobotoMono',
    color: _ink2,
  );

  static const TextStyle eyebrow = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.0,
    color: _ink3,
  );
}

class AppGradients {
  AppGradients._();

  static const LinearGradient accent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.accentGradientStart, AppColors.accent],
  );

  static const LinearGradient backgroundBase = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFF3EA), Color(0xFFF3ECFF)],
  );
}
