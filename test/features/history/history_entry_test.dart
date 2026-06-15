import 'package:ezctx/features/history/history_entry.dart';
import 'package:ezctx/features/transcription/transcription_options.dart';
import 'package:flutter_test/flutter_test.dart';

HistoryEntry _entry({String plainText = 'plain', String? timestampedText}) =>
    HistoryEntry(
      id: '1',
      fileName: 'f.ogg',
      sizeBytes: 1,
      durationSec: 1,
      language: 'ru',
      createdAt: DateTime(2026, 1, 1),
      plainPath: '/p.txt',
      timestampedPath: '/p_ts.txt',
      title: 'f',
      provider: TranscriptionProviderId.groq,
      plainText: plainText,
      timestampedText: timestampedText,
    );

void main() {
  group('HistoryEntry.hasTimestamps', () {
    test('null timestampedText → false', () {
      expect(_entry(timestampedText: null).hasTimestamps, isFalse);
    });
    test('пустой timestampedText → false', () {
      expect(_entry(timestampedText: '').hasTimestamps, isFalse);
    });
    test('timestampedText == plainText → false', () {
      expect(_entry(plainText: 'x', timestampedText: 'x').hasTimestamps, isFalse);
    });
    test('осмысленные метки → true', () {
      expect(
        _entry(plainText: 'привет', timestampedText: '[00:00:00] привет')
            .hasTimestamps,
        isTrue,
      );
    });
  });
}
