import 'package:ezctx/ui/widgets/glass_dropdown_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: Align(alignment: Alignment.topRight, child: child),
      ),
    );

void main() {
  group('GlassDropdownMenu', () {
    testWidgets(
      'hidden_initially: пункты не видны до открытия',
      (tester) async {
        await tester.pumpWidget(_wrap(
          GlassDropdownMenu(
            items: [GlassDropdownItem(label: 'Очистить историю', onTap: () {})],
          ),
        ));
        expect(find.text('Очистить историю'), findsNothing);
      },
    );

    testWidgets(
      'shows_on_tap: тап по кнопке → пункты видны',
      (tester) async {
        await tester.pumpWidget(_wrap(
          GlassDropdownMenu(
            items: [GlassDropdownItem(label: 'Очистить историю', onTap: () {})],
          ),
        ));
        await tester.tap(find.byType(GlassDropdownMenu));
        await tester.pumpAndSettle();
        expect(find.text('Очистить историю'), findsOneWidget);
      },
    );

    testWidgets(
      'item_has_material_ancestor: пункт под Material (нет жёлтого подчёркивания)',
      (tester) async {
        // Регрессия: контент OverlayEntry — сиблинг Scaffold, его Material не
        // является предком. Без своего Material пункт рисуется жёлтым с двойным
        // подчёркиванием. Проверка падала бы до фикса.
        await tester.pumpWidget(_wrap(
          GlassDropdownMenu(
            items: [GlassDropdownItem(label: 'Очистить историю', onTap: () {})],
          ),
        ));
        await tester.tap(find.byType(GlassDropdownMenu));
        await tester.pumpAndSettle();
        expect(
          find.ancestor(
            of: find.text('Очистить историю'),
            matching: find.byType(Material),
          ),
          findsWidgets,
        );
      },
    );

    testWidgets(
      'calls_callback: тап по пункту → onTap вызван',
      (tester) async {
        var called = false;
        await tester.pumpWidget(_wrap(
          GlassDropdownMenu(
            items: [
              GlassDropdownItem(
                label: 'Очистить историю',
                onTap: () => called = true,
              ),
            ],
          ),
        ));
        await tester.tap(find.byType(GlassDropdownMenu));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Очистить историю'));
        await tester.pumpAndSettle();
        expect(called, isTrue);
      },
    );

    testWidgets(
      'closes_after_item_tap: тап по пункту → dropdown закрывается',
      (tester) async {
        await tester.pumpWidget(_wrap(
          GlassDropdownMenu(
            items: [GlassDropdownItem(label: 'Очистить историю', onTap: () {})],
          ),
        ));
        await tester.tap(find.byType(GlassDropdownMenu));
        await tester.pumpAndSettle();
        expect(find.text('Очистить историю'), findsOneWidget);
        await tester.tap(find.text('Очистить историю'));
        await tester.pumpAndSettle();
        expect(find.text('Очистить историю'), findsNothing);
      },
    );

    testWidgets(
      'closes_on_barrier_tap: тап вне dropdown → dropdown закрывается',
      (tester) async {
        await tester.pumpWidget(_wrap(
          GlassDropdownMenu(
            items: [GlassDropdownItem(label: 'Очистить историю', onTap: () {})],
          ),
        ));
        await tester.tap(find.byType(GlassDropdownMenu));
        await tester.pumpAndSettle();
        expect(find.text('Очистить историю'), findsOneWidget);
        // Тап в левой части экрана — вне dropdown (который в правом верхнем углу).
        await tester.tapAt(const Offset(100, 400));
        await tester.pumpAndSettle();
        expect(find.text('Очистить историю'), findsNothing);
      },
    );
  });
}
