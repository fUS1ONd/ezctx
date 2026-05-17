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
class TranscriptionResult {
  final String text;
  final String language;
  final double duration;
  final List<WordTimestamp> words;

  const TranscriptionResult({
    required this.text,
    required this.language,
    required this.duration,
    required this.words,
  });

  factory TranscriptionResult.fromJson(Map<String, dynamic> json) {
    final wordsList = json['words'] as List<dynamic>?;
    return TranscriptionResult(
      text: json['text'] as String? ?? '',
      language: json['language'] as String? ?? '',
      duration: (json['duration'] as num?)?.toDouble() ?? 0.0,
      words: wordsList == null
          ? const <WordTimestamp>[]
          : wordsList
              .map((w) => WordTimestamp.fromJson(w as Map<String, dynamic>))
              .toList(),
    );
  }
}
