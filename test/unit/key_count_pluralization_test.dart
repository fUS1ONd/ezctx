// Unit-тесты русской плюрализации «ключ/ключа/ключей».
// Тестирует top-level функцию pluralizeKeys из settings_screen.dart.
import 'package:ezctx/ui/screens/settings_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pluralizeKeys — русская плюрализация', () {
    test('0 → «Нет ключей»', () {
      expect(pluralizeKeys(0), 'Нет ключей');
    });

    test('1 → «1 ключ»', () {
      expect(pluralizeKeys(1), '1 ключ');
    });

    test('2 → «2 ключа»', () {
      expect(pluralizeKeys(2), '2 ключа');
    });

    test('4 → «4 ключа»', () {
      expect(pluralizeKeys(4), '4 ключа');
    });

    test('5 → «5 ключей»', () {
      expect(pluralizeKeys(5), '5 ключей');
    });

    test('11 → «11 ключей» (исключение mod100)', () {
      expect(pluralizeKeys(11), '11 ключей');
    });

    test('21 → «21 ключ» (mod10=1, mod100=21)', () {
      expect(pluralizeKeys(21), '21 ключ');
    });

    test('22 → «22 ключа»', () {
      expect(pluralizeKeys(22), '22 ключа');
    });

    test('25 → «25 ключей»', () {
      expect(pluralizeKeys(25), '25 ключей');
    });

    test('111 → «111 ключей» (исключение mod100=11)', () {
      expect(pluralizeKeys(111), '111 ключей');
    });
  });
}
