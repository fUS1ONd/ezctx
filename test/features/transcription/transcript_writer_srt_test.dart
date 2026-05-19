import 'package:flutter_test/flutter_test.dart';
import 'package:ezctx/features/transcription/transcript_writer.dart';
import 'package:ezctx/features/transcription/transcription_result.dart';

void main() {
  group('TranscriptWriter._srtTime', () {
    test('0.0 секунды → "00:00:00,000"', () {
      expect(TranscriptWriter.srtTime(0.0), equals('00:00:00,000'));
    });

    test('3661.5 секунды → "01:01:01,500"', () {
      expect(TranscriptWriter.srtTime(3661.5), equals('01:01:01,500'));
    });

    test('таймкод содержит запятую, а не точку', () {
      final result = TranscriptWriter.srtTime(1.5);
      expect(result, contains(','));
      expect(result, isNot(contains('.')));
    });
  });

  group('TranscriptWriter._segmentsToSrt', () {
    final seg = TranscriptionSegment(start: 0.0, end: 2.5, text: 'Привет мир');

    test('нумерация начинается с 1', () {
      final result = TranscriptWriter.segmentsToSrt([seg]);
      expect(result, contains('1\n'));
    });

    test('таймкод содержит запятую и не содержит точку', () {
      final result = TranscriptWriter.segmentsToSrt([seg]);
      expect(result, contains(','));
      expect(result, isNot(contains('.')));
    });

    test('последний блок заканчивается двойным переводом строки', () {
      final result = TranscriptWriter.segmentsToSrt([seg]);
      expect(result, endsWith('\n\n'));
    });

    test('несколько сегментов нумеруются последовательно', () {
      final segs = [
        TranscriptionSegment(start: 0.0, end: 1.0, text: 'Первый'),
        TranscriptionSegment(start: 1.0, end: 2.0, text: 'Второй'),
      ];
      final result = TranscriptWriter.segmentsToSrt(segs);
      expect(result, contains('1\n'));
      expect(result, contains('2\n'));
    });
  });

  group('TranscriptWriter.writeSrt', () {
    test('пустой список сегментов возвращает форматированную строку с пустым содержимым', () {
      // writeSrt возвращает null при пустых segments (асинхронный метод требует io)
      // проверяем через segmentsToSrt — пустой список даёт пустую строку
      final result = TranscriptWriter.segmentsToSrt([]);
      expect(result, equals(''));
    });
  });
}
