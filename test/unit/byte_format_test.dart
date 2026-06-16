import 'package:ezctx/core/utils/byte_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatBytes — десятичная лесенка Б→КБ→МБ→ГБ (issue #12)', () {
    test('0 байт', () => expect(formatBytes(0), '0 Б'));
    test('999 байт — ещё Б', () => expect(formatBytes(999), '999 Б'));
    test('1000 байт — переход в КБ', () => expect(formatBytes(1000), '1.0 КБ'));
    test('999 999 байт — всё ещё КБ', () => expect(formatBytes(999999), '1000.0 КБ'));
    test('1 000 000 байт — переход в МБ', () => expect(formatBytes(1000000), '1.0 МБ'));

    // Кейс из issue: ~150.8 млн байт. Системный менеджер показывает «151 MB»,
    // десятичный формат даёт «150.8 МБ» (раньше было двоичное «143.8 МБ»).
    test('кейс issue #12 — 150 785 228 байт', () {
      expect(formatBytes(150785228), '150.8 МБ');
    });

    test('999 999 999 байт — всё ещё МБ', () => expect(formatBytes(999999999), '1000.0 МБ'));
    test('1 000 000 000 байт — переход в ГБ', () => expect(formatBytes(1000000000), '1.0 ГБ'));
    test('2.5 ГБ видеофайл', () => expect(formatBytes(2500000000), '2.5 ГБ'));
  });
}
