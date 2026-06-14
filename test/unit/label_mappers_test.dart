import 'package:ezctx/core/utils/label_mappers.dart';
import 'package:ezctx/features/transcription/transcription_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('languageLabel', () {
    test('двухбуквенный lowercase → uppercase', () {
      expect(languageLabel('ru'), 'RU');
      expect(languageLabel('en'), 'EN');
    });

    test('BCP-47 с регионом → только первая часть uppercase', () {
      expect(languageLabel('en-US'), 'EN');
      expect(languageLabel('zh-TW'), 'ZH');
    });

    test('пустая строка → ?', () {
      expect(languageLabel(''), '?');
    });

    test('unknown → ?', () {
      expect(languageLabel('unknown'), '?');
    });

    test('некорректная длина (не 2 буквы) → ?', () {
      expect(languageLabel('fra'), '?');
      expect(languageLabel('x'), '?');
    });

    test('идемпотентность — уже нормализованное значение', () {
      expect(languageLabel('EN'), 'EN');
      expect(languageLabel('RU'), 'RU');
      expect(languageLabel('?'), '?');
    });
  });

  group('providerLabel', () {
    test('groq → Groq', () {
      expect(providerLabel(TranscriptionProviderId.groq), 'Groq');
    });

    test('deepgram → Deepgram', () {
      expect(providerLabel(TranscriptionProviderId.deepgram), 'Deepgram');
    });
  });
}
