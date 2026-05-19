// test/widget/home_screen_smoke_test.dart
import 'package:ezctx/core/providers/theme_provider.dart';
import 'package:ezctx/ui/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Заглушка: не обращается к FlutterSecureStorage.
class _FakeThemeModeNotifier extends ThemeModeNotifier {
  @override
  ThemeMode build() => ThemeMode.light;
}

Widget _wrap(Widget child) {
  return ProviderScope(
    overrides: [
      themeModeProvider.overrideWith(_FakeThemeModeNotifier.new),
    ],
    child: MaterialApp(home: child),
  );
}

void _setPhoneViewport(WidgetTester tester) {
  // Задаём физический размер эквивалентный 390×844 @ 3x, чтобы
  // layout внутри HomeScreen не переполнялся на дефолтных 800×600.
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('HomeScreen smoke', () {
    testWidgets('начальное состояние — нет ошибок, dropzone видна', (tester) async {
      _setPhoneViewport(tester);
      await tester.pumpWidget(_wrap(const HomeScreen()));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Выберите файл'), findsOneWidget);
    });

    testWidgets('шапка рендерится — лого и заголовок видны', (tester) async {
      _setPhoneViewport(tester);
      await tester.pumpWidget(_wrap(const HomeScreen()));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Слух'), findsOneWidget);
      expect(find.textContaining('Расшифруй'), findsOneWidget);
    });
  });
}
