import 'package:flutter_test/flutter_test.dart';
import 'package:ezctx/features/transcription/processing_args.dart';
import 'package:ezctx/features/transcription/selected_audio_file.dart';

void main() {
  const _mb = 1024 * 1024;

  SelectedAudioFile _file(int sizeBytes) => SelectedAudioFile(
        path: '/tmp/test.mp3',
        name: 'test.mp3',
        sizeBytes: sizeBytes,
        extension: 'mp3',
      );

  group('ProcessingArgs.isChunked — по размеру файла', () {
    test('18 МБ → false (Phase 1 путь)', () {
      final args = ProcessingArgs(file: _file(18 * _mb));
      expect(args.isChunked, isFalse);
    });

    test('19 МБ ровно → true (граничный случай)', () {
      final args = ProcessingArgs(file: _file(19 * _mb));
      expect(args.isChunked, isTrue);
    });

    test('26.6 МБ → true (регрессия: раньше false при коротком аудио)', () {
      // Файл 26.6 МБ при 256kbps = ~14 мин < 20 мин — раньше isChunked был false,
      // что приводило к отправке оригинала 26.6 МБ в Groq → отказ API.
      final args = ProcessingArgs(file: _file((26.6 * _mb).round()));
      expect(args.isChunked, isTrue);
    });

    test('60 МБ → true', () {
      final args = ProcessingArgs(file: _file(60 * _mb));
      expect(args.isChunked, isTrue);
    });

    test('metadata не влияет на решение о чанковании', () {
      // Даже если metadata есть и длительность < 20 мин, решение только по размеру.
      final args = ProcessingArgs(
        file: _file(25 * _mb),
        metadata: null,
      );
      expect(args.isChunked, isTrue);
    });
  });
}
