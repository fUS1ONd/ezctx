import 'package:flutter/foundation.dart';

/// Идентификатор провайдера транскрибации. Провайдер всегда выводится
/// из выбранной модели через [TranscriptionModel.provider].
enum TranscriptionProviderId { groq, deepgram }

/// Поддерживаемые модели транскрибации (мульти-провайдерные).
/// Каждая модель привязана к провайдеру и хранит строковое значение API.
enum TranscriptionModel {
  whisperLargeV3(TranscriptionProviderId.groq, 'whisper-large-v3'),
  whisperTurbo(TranscriptionProviderId.groq, 'whisper-large-v3-turbo'),
  nova3(TranscriptionProviderId.deepgram, 'nova-3');

  const TranscriptionModel(this.provider, this.apiValue);
  final TranscriptionProviderId provider;
  final String apiValue;
}

/// Алиасы старых строковых значений `model` (формат `transcription_options_v1`
/// до введения мульти-провайдерной модели). Нужны для миграции хранилища
/// без потери выбора пользователя и без исключений при загрузке.
const Map<String, TranscriptionModel> _legacyModelAliases = {
  'largeV3': TranscriptionModel.whisperLargeV3,
  'turbo': TranscriptionModel.whisperTurbo,
};

/// Язык распознавания. [auto] — поле language не передаётся в запрос Groq.
enum TranscriptionLanguage {
  auto(''),
  ru('ru'),
  en('en'),
  de('de'),
  fr('fr'),
  es('es'),
  uk('uk'),
  zh('zh'),
  ja('ja'),
  ko('ko'),
  ar('ar');

  const TranscriptionLanguage(this.isoCode);
  final String isoCode;
}

/// Настройки транскрибации: модель + язык. Immutable value object.
@immutable
class TranscriptionOptions {
  const TranscriptionOptions({
    required this.model,
    required this.language,
  });

  const TranscriptionOptions.defaults()
      : model = TranscriptionModel.whisperLargeV3,
        language = TranscriptionLanguage.auto;

  final TranscriptionModel model;
  final TranscriptionLanguage language;

  Map<String, String> toJson() => {
        'model': model.name,
        'language': language.name,
      };

  factory TranscriptionOptions.fromJson(Map<String, dynamic> json) {
    // Сначала проверяем legacy-алиасы (старый формат хранилища
    // transcription_options_v1, например "largeV3"/"turbo"), затем —
    // новые имена членов enum. Любое неизвестное значение → fallback
    // на whisperLargeV3 без исключения (см. T-07-01).
    final rawModel = json['model'];
    final model = _legacyModelAliases[rawModel] ??
        TranscriptionModel.values.firstWhere(
          (m) => m.name == rawModel,
          orElse: () => TranscriptionModel.whisperLargeV3,
        );
    final language = TranscriptionLanguage.values.firstWhere(
      (l) => l.name == json['language'],
      orElse: () => TranscriptionLanguage.auto,
    );
    return TranscriptionOptions(model: model, language: language);
  }

  TranscriptionOptions copyWith({
    TranscriptionModel? model,
    TranscriptionLanguage? language,
  }) =>
      TranscriptionOptions(
        model: model ?? this.model,
        language: language ?? this.language,
      );

  @override
  bool operator ==(Object other) =>
      other is TranscriptionOptions &&
      other.model == model &&
      other.language == language;

  @override
  int get hashCode => Object.hash(model, language);
}
