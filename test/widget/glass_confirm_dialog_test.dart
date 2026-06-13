import 'package:ezctx/ui/widgets/glass_confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      home: child,
    );

void main() {
  group('GlassConfirmDialog', () {
    testWidgets(
      'renders_content: показывает title, body, confirmLabel и кнопку Отмена',
      (tester) async {
        await tester.pumpWidget(_wrap(
          const GlassConfirmDialog(
            title: 'Удалить?',
            body: 'Это нельзя отменить.',
            confirmLabel: 'Удалить',
          ),
        ));
        expect(find.text('Удалить?'), findsOneWidget);
        expect(find.text('Это нельзя отменить.'), findsOneWidget);
        expect(find.text('Удалить'), findsOneWidget);
        expect(find.text('Отмена'), findsOneWidget);
      },
    );

    testWidgets(
      'cancel_returns_false: тап Отмена → show() возвращает false',
      (tester) async {
        bool? result;
        await tester.pumpWidget(_wrap(
          Builder(builder: (ctx) => TextButton(
            onPressed: () async {
              result = await GlassConfirmDialog.show(
                ctx,
                title: 'T',
                body: 'B',
                confirmLabel: 'OK',
              );
            },
            child: const Text('open'),
          )),
        ));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Отмена'));
        await tester.pumpAndSettle();
        expect(result, false);
      },
    );

    testWidgets(
      'confirm_returns_true: тап confirmLabel → show() возвращает true',
      (tester) async {
        bool? result;
        await tester.pumpWidget(_wrap(
          Builder(builder: (ctx) => TextButton(
            onPressed: () async {
              result = await GlassConfirmDialog.show(
                ctx,
                title: 'T',
                body: 'B',
                confirmLabel: 'OK',
              );
            },
            child: const Text('open'),
          )),
        ));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        expect(result, true);
      },
    );
  });
}
