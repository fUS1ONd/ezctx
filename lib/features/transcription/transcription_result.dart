/// Один сегмент с таймкодами из verbose_json ответа Groq.
/// Используется в Phase 2 для сборки транскрипции по чанкам с таймкодами.
class TranscriptionSegment {
  /// Абсолютное начало сегмента (чанк_offset + segment.start из Groq).
  final double start;

  /// Абсолютный конец сегмента.
  final double end;

  final String text;

  const TranscriptionSegment({
    required this.start,
    required this.end,
    required this.text,
  });

  factory TranscriptionSegment.fromJson(Map<String, dynamic> json) {
    return TranscriptionSegment(
      start: (json['start'] as num?)?.toDouble() ?? 0.0,
      end: (json['end'] as num?)?.toDouble() ?? 0.0,
      text: json['text'] as String? ?? '',
    );
  }
}

/// Одно слово с таймкодами из verbose_json ответа Groq.
class WordTimestamp {
  final String word;
  final double start;
  final double end;

  const WordTimestamp({
    required this.word,
    required this.start,
    required this.end,
  });

  factory WordTimestamp.fromJson(Map<String, dynamic> json) {
    return WordTimestamp(
      word: json['word'] as String? ?? '',
      start: (json['start'] as num?)?.toDouble() ?? 0.0,
      end: (json['end'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Результат транскрибации Groq Whisper.
/// Phase 1 использует только `text`. Поле `words` понадобится в Phase 5 (SRT).
/// Поле `segments` используется в Phase 2 для сборки таймкодов по чанкам.
class TranscriptionResult {
  final String text;
  final String language;
  final double duration;
  final List<WordTimestamp> words;

  /// Сегменты из verbose_json. По умолчанию пустой список (обратная совместимость).
  final List<TranscriptionSegment> segments;

  const TranscriptionResult({
    required this.text,
    required this.language,
    required this.duration,
    required this.words,
    this.segments = const [],
  });

  /// Создаёт пустой результат-заглушку (используется при сборке чанков вместо null-слотов).
  const TranscriptionResult.empty()
      : text = '',
        language = '',
        duration = 0.0,
        words = const [],
        segments = const [];

  factory TranscriptionResult.fromJson(Map<String, dynamic> json) {
    final wordsList = json['words'] as List<dynamic>?;
    final segmentsList = json['segments'] as List<dynamic>?;
    return TranscriptionResult(
      text: json['text'] as String? ?? '',
      language: json['language'] as String? ?? '',
      duration: (json['duration'] as num?)?.toDouble() ?? 0.0,
      words: wordsList == null
          ? const <WordTimestamp>[]
          : wordsList
              .map((w) => WordTimestamp.fromJson(w as Map<String, dynamic>))
              .toList(),
      segments: segmentsList == null
          ? const <TranscriptionSegment>[]
          : segmentsList
              .map((s) =>
                  TranscriptionSegment.fromJson(s as Map<String, dynamic>))
              .toList(),
    );
  }
}
