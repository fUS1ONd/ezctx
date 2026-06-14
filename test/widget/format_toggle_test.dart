import 'package:ezctx/ui/widgets/format_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('показывает обе подписи и метку «Вид:»', (tester) async {
    await tester.pumpWidget(wrap(
      FormatToggle(showTimestamps: false, onChanged: (_) {}),
    ));
    expect(find.text('Вид:'), findsOneWidget);
    expect(find.text('С метками'), findsOneWidget);
    expect(find.text('Без меток'), findsOneWidget);
  });

  testWidgets('тап «С метками» вызывает onChanged(true)', (tester) async {
    bool? received;
    await tester.pumpWidget(wrap(
      FormatToggle(showTimestamps: false, onChanged: (v) => received = v),
    ));
    await tester.tap(find.text('С метками'));
    expect(received, isTrue);
  });

  testWidgets('тап «Без меток» вызывает onChanged(false)', (tester) async {
    bool? received;
    await tester.pumpWidget(wrap(
      FormatToggle(showTimestamps: true, onChanged: (v) => received = v),
    ));
    await tester.tap(find.text('Без меток'));
    expect(received, isFalse);
  });
}
