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

  group('ProcessingArgs — конструктор', () {
    test('создаётся с file и без metadata', () {
      final args = ProcessingArgs(file: _file(18 * _mb));
      expect(args.file.sizeBytes, equals(18 * _mb));
      expect(args.metadata, isNull);
    });

    test('создаётся с file и metadata', () {
      final args = ProcessingArgs(
        file: _file(25 * _mb),
        metadata: null,
      );
      expect(args.file, isNotNull);
    });
  });
}
