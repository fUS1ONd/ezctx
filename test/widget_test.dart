// Базовый smoke test приложения ezctx.
// Wave 0 заглушка — BackdropFilter требует GPU, поэтому пропускается в unit suite.
// Наполняется в Plan 03 с корректным widget test setup.
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('smoke test — наполняется в Plan 03', () {
    // BackdropFilter и GlassCard требуют GPU для рендеринга.
    // Widget tests с реальным UI добавляются в Plan 03 после настройки тест-окружения.
    expect(true, isTrue);
  }, skip: 'Widget tests require GPU (implemented in Plan 03)');
}
