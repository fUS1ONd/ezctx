import 'package:flutter/foundation.dart';

/// Поддерживаемые модели Groq Whisper.
enum WhisperModel {
  largeV3('whisper-large-v3'),
  turbo('whisper-large-v3-turbo');

  const WhisperModel(this.apiValue);
  final String apiValue;
}

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
      : model = WhisperModel.largeV3,
        language = TranscriptionLanguage.auto;

  final WhisperModel model;
  final TranscriptionLanguage language;

  Map<String, String> toJson() => {
        'model': model.name,
        'language': language.name,
      };

  factory TranscriptionOptions.fromJson(Map<String, dynamic> json) {
    final model = WhisperModel.values.firstWhere(
      (m) => m.name == json['model'],
      orElse: () => WhisperModel.largeV3,
    );
    final language = TranscriptionLanguage.values.firstWhere(
      (l) => l.name == json['language'],
      orElse: () => TranscriptionLanguage.auto,
    );
    return TranscriptionOptions(model: model, language: language);
  }

  TranscriptionOptions copyWith({
    WhisperModel? model,
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
