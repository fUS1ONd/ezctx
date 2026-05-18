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
///
/// [text] — текст с таймкодами `[HH:MM:SS]`. Строится из сегментов, если
/// они присутствуют в ответе (chunked и single-shot verbose_json оба возвращают
/// segments). Если сегментов нет — содержит plain text.
///
/// [plainText] — текст без таймкодов. Используется переключателем вида
/// на ResultScreen.
class TranscriptionResult {
  final String text;

  /// Чистый текст без временных меток. Для single-shot совпадает с [text].
  final String plainText;

  final String language;
  final double duration;
  final List<WordTimestamp> words;

  /// Сегменты из verbose_json. По умолчанию пустой список (обратная совместимость).
  final List<TranscriptionSegment> segments;

  const TranscriptionResult({
    required this.text,
    String? plainText,
    required this.language,
    required this.duration,
    required this.words,
    this.segments = const [],
  }) : plainText = plainText ?? text;

  /// Создаёт пустой результат-заглушку (используется при сборке чанков вместо null-слотов).
  const TranscriptionResult.empty()
      : text = '',
        plainText = '',
        language = '',
        duration = 0.0,
        words = const [],
        segments = const [];

  factory TranscriptionResult.fromJson(Map<String, dynamic> json) {
    final rawText = json['text'] as String? ?? '';
    final segmentsList = json['segments'] as List<dynamic>?;
    final wordsList = json['words'] as List<dynamic>?;

    final segments = segmentsList == null
        ? const <TranscriptionSegment>[]
        : segmentsList
            .map((s) => TranscriptionSegment.fromJson(s as Map<String, dynamic>))
            .toList();

    String timestampedText;
    String plainText;

    if (segments.isNotEmpty) {
      // Строим оба варианта из сегментов (single-shot verbose_json тоже возвращает segments).
      final buf = StringBuffer();
      final plain = StringBuffer();
      for (final seg in segments) {
        final ts = _formatTimecode(seg.start);
        buf.write('[$ts] ${seg.text.trim()}\n');
        plain.write('${seg.text.trim()}\n');
      }
      timestampedText = buf.toString().trimRight();
      plainText = plain.toString().trimRight();
    } else {
      // Запасной вариант: сегментов нет — используем сырой текст в обоих режимах.
      timestampedText = rawText;
      plainText = rawText;
    }

    return TranscriptionResult(
      text: timestampedText,
      plainText: plainText,
      language: json['language'] as String? ?? '',
      duration: (json['duration'] as num?)?.toDouble() ?? 0.0,
      words: wordsList == null
          ? const <WordTimestamp>[]
          : wordsList
              .map((w) => WordTimestamp.fromJson(w as Map<String, dynamic>))
              .toList(),
      segments: segments,
    );
  }

  /// Форматирует секунды в строку `HH:MM:SS`.
  static String _formatTimecode(double totalSeconds) {
    final secs = totalSeconds.round();
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    final s = secs % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
