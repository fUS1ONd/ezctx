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

    test('BCP-47 нижний регистр с регионом → uppercase', () {
      expect(languageLabel('en-us'), 'EN');
    });

    test('полное название языка Groq Whisper → ISO uppercase', () {
      expect(languageLabel('russian'), 'RU');
      expect(languageLabel('english'), 'EN');
      expect(languageLabel('german'), 'DE');
      expect(languageLabel('ukrainian'), 'UK');
      expect(languageLabel('chinese'), 'ZH');
      expect(languageLabel('spanish'), 'ES');
    });

    test('название языка в смешанном регистре → ISO uppercase', () {
      expect(languageLabel('Russian'), 'RU');
      expect(languageLabel('ENGLISH'), 'EN');
    });

    test('алиас Whisper (mandarin/castilian) → ISO uppercase', () {
      expect(languageLabel('mandarin'), 'ZH');
      expect(languageLabel('castilian'), 'ES');
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

  group('providerLabelFromName', () {
    test('groq → Groq', () {
      expect(providerLabelFromName('groq'), 'Groq');
    });

    test('deepgram → Deepgram', () {
      expect(providerLabelFromName('deepgram'), 'Deepgram');
    });

    test('неизвестный → сырое значение', () {
      expect(providerLabelFromName('assemblyai'), 'assemblyai');
    });
  });
}
