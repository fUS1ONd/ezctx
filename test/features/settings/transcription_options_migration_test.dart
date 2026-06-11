import 'package:ezctx/features/transcription/transcription_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TranscriptionOptions migration', () {
    test('legacy JSON {"model":"largeV3"} → whisperLargeV3 без исключения',
        () {
      final options = TranscriptionOptions.fromJson(
        const {'model': 'largeV3', 'language': 'auto'},
      );

      expect(options.model, TranscriptionModel.whisperLargeV3);
      expect(options.language, TranscriptionLanguage.auto);
    });

    test('legacy JSON {"model":"turbo"} → whisperTurbo', () {
      final options = TranscriptionOptions.fromJson(
        const {'model': 'turbo', 'language': 'ru'},
      );

      expect(options.model, TranscriptionModel.whisperTurbo);
      expect(options.language, TranscriptionLanguage.ru);
    });

    test('новый формат {"model":"whisperLargeV3"} грузится напрямую', () {
      final options = TranscriptionOptions.fromJson(
        const {'model': 'whisperLargeV3', 'language': 'en'},
      );

      expect(options.model, TranscriptionModel.whisperLargeV3);
      expect(options.language, TranscriptionLanguage.en);
    });

    test('мусорное значение model → fallback whisperLargeV3 без throw', () {
      final options = TranscriptionOptions.fromJson(const {'model': '???'});

      expect(options.model, TranscriptionModel.whisperLargeV3);
      expect(options.language, TranscriptionLanguage.auto);
    });

    test('round-trip fromJson(toJson(x)) == x для каждого члена модели', () {
      for (final model in TranscriptionModel.values) {
        for (final language in TranscriptionLanguage.values) {
          final original = TranscriptionOptions(model: model, language: language);
          final restored = TranscriptionOptions.fromJson(original.toJson());

          expect(restored, original);
        }
      }
    });

    test('toJson(defaults) сериализует имя нового члена enum', () {
      const defaults = TranscriptionOptions.defaults();

      expect(defaults.toJson()['model'], 'whisperLargeV3');
    });

    test('TranscriptionModel.whisperLargeV3 → провайдер groq, apiValue верный',
        () {
      expect(
        TranscriptionModel.whisperLargeV3.provider,
        TranscriptionProviderId.groq,
      );
      expect(TranscriptionModel.whisperLargeV3.apiValue, 'whisper-large-v3');
    });

    test('TranscriptionModel.whisperTurbo → провайдер groq, apiValue верный',
        () {
      expect(
        TranscriptionModel.whisperTurbo.provider,
        TranscriptionProviderId.groq,
      );
      expect(
        TranscriptionModel.whisperTurbo.apiValue,
        'whisper-large-v3-turbo',
      );
    });

    test('TranscriptionModel.nova3 → провайдер deepgram, apiValue верный', () {
      expect(
        TranscriptionModel.nova3.provider,
        TranscriptionProviderId.deepgram,
      );
      expect(TranscriptionModel.nova3.apiValue, 'nova-3');
    });
  });
}
