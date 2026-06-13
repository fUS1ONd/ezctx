// Unit-тесты чистых функций нормализации лейблов истории (план 04-01, Task 1).
// languageLabel: нормализует языковой тег к двухбуквенному UPPERCASE с fallback.
// providerLabel: возвращает читаемое имя провайдера с fallback-капитализацией.
import 'package:ezctx/features/history/history_label_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('languageLabel', () {
    test('ru → RU', () {
      expect(languageLabel('ru'), 'RU');
    });

    test('en-US → EN (берётся часть до дефиса, UPPERCASE)', () {
      expect(languageLabel('en-US'), 'EN');
    });

    test('empty → —', () {
      expect(languageLabel(''), '—');
    });

    test('auto → AUTO', () {
      expect(languageLabel('auto'), 'AUTO');
    });
  });

  group('providerLabel', () {
    test('groq → Groq', () {
      expect(providerLabel('groq'), 'Groq');
    });

    test('deepgram → Deepgram', () {
      expect(providerLabel('deepgram'), 'Deepgram');
    });

    test('whisper → Whisper (fallback: первая буква заглавная)', () {
      expect(providerLabel('whisper'), 'Whisper');
    });

    test('empty → —', () {
      expect(providerLabel(''), '—');
    });
  });
}
