// @Tags(['golden'])
// Запускать только на Linux — шрифты на macOS дают сдвиг пикселей.
import 'dart:typed_data';

import 'package:ezctx/core/constants/design_tokens.dart';
import 'package:ezctx/ui/widgets/glass_card.dart';
import 'package:ezctx/ui/widgets/gradient_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Кастомный comparator с допуском (§3.4 плана).
class TolerantGoldenComparator extends LocalFileComparator {
  TolerantGoldenComparator(Uri testFile, this.toleranceFraction)
      : super(testFile);
  final double toleranceFraction;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed) return true;
    if (result.diffPercent <= toleranceFraction) return true;
    throw FlutterError(
      result.error ??
          'golden mismatch: ${(result.diffPercent * 100).toStringAsFixed(2)}% '
              '> ${(toleranceFraction * 100).toStringAsFixed(1)}% допуска',
    );
  }
}

// Фиксированный viewport 390×844, devicePixelRatio=1 для хост-агностики.
void _setPhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _wrap(Widget child, Brightness brightness) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: brightness),
      home: Scaffold(backgroundColor: Colors.transparent, body: child),
    );

// Содержимое карточки — симулирует элемент истории.
Widget _historyCardContent() => const Padding(
      padding: EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Запись лекции',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          SizedBox(height: 4),
          Text('2025-01-15 • 23:42', style: TextStyle(fontSize: 13)),
        ],
      ),
    );

// Uniform-фон: однородный цвет из первой точки bgGradient (калибровка alpha).
Widget _uniformBg(Widget child, AppPalette palette) => ColoredBox(
      color: (palette.bgGradient as LinearGradient).colors.first,
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );

// Realistic-фон: полный GradientBackground с блобами.
Widget _realisticBg(Widget child) => GradientBackground(
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );

void main() {
  // ── Группа A: flat_uniform — жёсткий gate, 0.5% ──────────────
  group('GlassCard flat_uniform', () {
    late GoldenFileComparator _orig;

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      _orig = goldenFileComparator;
    });

    setUp(() {
      final basedir = (_orig as LocalFileComparator).basedir;
      // basedir — директория; конструктор LocalFileComparator ожидает FILE URI,
      // иначе dirname(dir) даёт родительскую директорию и путь к golden'ам смещается.
      final fakeFile = basedir.resolve('scroll_screens_golden_test.dart');
      goldenFileComparator = TolerantGoldenComparator(fakeFile, 0.005);
    });

    tearDown(() {
      goldenFileComparator = _orig;
    });

    for (final isDark in [false, true]) {
      final theme = isDark ? 'dark' : 'light';
      final brightness = isDark ? Brightness.dark : Brightness.light;
      final palette = isDark ? AppPalette.dark : AppPalette.light;

      testWidgets('HistoryScreen_5entries_uniform_$theme', (tester) async {
        _setPhoneViewport(tester);
        await tester.pumpWidget(_wrap(
          _uniformBg(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                5,
                (_) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    borderRadius: 22,
                    padding: const EdgeInsets.all(14),
                    child: _historyCardContent(),
                  ),
                ),
              ),
            ),
            palette,
          ),
          brightness,
        ));
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/HistoryScreen_5entries_uniform_$theme.png'),
        );
      });

      testWidgets('SettingsScreen_group_uniform_$theme', (tester) async {
        _setPhoneViewport(tester);
        await tester.pumpWidget(_wrap(
          _uniformBg(
            GlassCard(
              borderRadius: 22,
              padding: EdgeInsets.zero,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < 3; i++)
                    ListTile(
                      title: Text('Настройка $i'),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                ],
              ),
            ),
            palette,
          ),
          brightness,
        ));
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/SettingsScreen_group_uniform_$theme.png'),
        );
      });

      testWidgets('ApiKeysScreen_3keys_uniform_$theme', (tester) async {
        _setPhoneViewport(tester);
        await tester.pumpWidget(_wrap(
          _uniformBg(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                3,
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.key),
                        const SizedBox(width: 8),
                        Text('gsk_test_key_$i'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            palette,
          ),
          brightness,
        ));
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/ApiKeysScreen_3keys_uniform_$theme.png'),
        );
      });
    }
  });

  // ── Группа B: flat_realistic — мягкий gate, 5% ───────────────
  group('GlassCard flat_realistic', () {
    late GoldenFileComparator _orig;

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      _orig = goldenFileComparator;
    });

    setUp(() {
      final basedir = (_orig as LocalFileComparator).basedir;
      final fakeFile = basedir.resolve('scroll_screens_golden_test.dart');
      goldenFileComparator = TolerantGoldenComparator(fakeFile, 0.05);
    });

    tearDown(() {
      goldenFileComparator = _orig;
    });

    for (final isDark in [false, true]) {
      final theme = isDark ? 'dark' : 'light';
      final brightness = isDark ? Brightness.dark : Brightness.light;

      testWidgets('HistoryScreen_5entries_realistic_$theme', (tester) async {
        _setPhoneViewport(tester);
        await tester.pumpWidget(_wrap(
          _realisticBg(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                5,
                (_) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    borderRadius: 22,
                    padding: const EdgeInsets.all(14),
                    child: _historyCardContent(),
                  ),
                ),
              ),
            ),
          ),
          brightness,
        ));
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
              'goldens/HistoryScreen_5entries_realistic_$theme.png'),
        );
      });

      testWidgets('SettingsScreen_group_realistic_$theme', (tester) async {
        _setPhoneViewport(tester);
        await tester.pumpWidget(_wrap(
          _realisticBg(
            GlassCard(
              borderRadius: 22,
              padding: EdgeInsets.zero,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < 3; i++)
                    ListTile(
                      title: Text('Настройка $i'),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                ],
              ),
            ),
          ),
          brightness,
        ));
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
              'goldens/SettingsScreen_group_realistic_$theme.png'),
        );
      });

      testWidgets('ApiKeysScreen_3keys_realistic_$theme', (tester) async {
        _setPhoneViewport(tester);
        await tester.pumpWidget(_wrap(
          _realisticBg(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                3,
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.key),
                        const SizedBox(width: 8),
                        Text('gsk_test_key_$i'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          brightness,
        ));
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
              'goldens/ApiKeysScreen_3keys_realistic_$theme.png'),
        );
      });
    }
  });
}
