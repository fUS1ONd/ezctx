// Базовый smoke test приложения ezctx.
// Проверяет что EzCtxApp запускается без краша.
import 'package:flutter_test/flutter_test.dart';

import 'package:ezctx/ui/app.dart';

void main() {
  testWidgets('EzCtxApp smoke test', (WidgetTester tester) async {
    // Проверяем что приложение запускается без краша
    await tester.pumpWidget(const EzCtxApp());
    // Проверяем наличие основных экранов (HomeScreen загружается по умолчанию)
    expect(find.text('Слух'), findsOneWidget);
  });
}
