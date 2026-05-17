import 'package:flutter_test/flutter_test.dart';
import 'package:ezctx/features/transcription/file_validator.dart';

void main() {
  final v = const FileValidator();
  const okSize = 1 * 1024 * 1024; // 1 МБ
  const tooBigSize = 20 * 1024 * 1024; // 20 МБ

  group('FileValidator.validate — whitelist расширений', () {
    test('mp3 — ok', () {
      expect(v.validate(path: 'lecture.mp3', sizeBytes: okSize).isOk, isTrue);
    });

    test('wav — ok', () {
      expect(v.validate(path: 'audio.wav', sizeBytes: okSize).isOk, isTrue);
    });

    test('m4a — ok', () {
      expect(v.validate(path: 'rec.m4a', sizeBytes: okSize).isOk, isTrue);
    });

    test('ogg — ok', () {
      expect(v.validate(path: 'sound.ogg', sizeBytes: okSize).isOk, isTrue);
    });

    test('flac — ok', () {
      expect(v.validate(path: 'lossless.flac', sizeBytes: okSize).isOk, isTrue);
    });

    test('mp4 — ok', () {
      expect(v.validate(path: 'video.mp4', sizeBytes: okSize).isOk, isTrue);
    });

    test('mpeg — ok', () {
      expect(v.validate(path: 'track.mpeg', sizeBytes: okSize).isOk, isTrue);
    });

    test('mpga — ok', () {
      expect(v.validate(path: 'track.mpga', sizeBytes: okSize).isOk, isTrue);
    });

    test('webm — ok', () {
      expect(v.validate(path: 'clip.webm', sizeBytes: okSize).isOk, isTrue);
    });

    test('регистр — MP3 принимается как mp3', () {
      expect(v.validate(path: 'file.MP3', sizeBytes: okSize).isOk, isTrue);
    });
  });

  group('FileValidator.validate — путь к файлу', () {
    test('полный путь /storage/emulated/.../lecture.mp3 — ok', () {
      expect(
        v.validate(
          path: '/storage/emulated/0/Music/lecture.mp3',
          sizeBytes: okSize,
        ).isOk,
        isTrue,
      );
    });

    test('точка в папке не путает парсер — /folder.v1/file → отклоняется', () {
      expect(v.validate(path: '/folder.v1/file', sizeBytes: okSize).isOk, isFalse);
    });
  });

  group('FileValidator.validate — неподдерживаемые форматы', () {
    test('.txt отклоняется', () {
      expect(v.validate(path: 'doc.txt', sizeBytes: okSize).isOk, isFalse);
    });

    test('.aac отклоняется', () {
      final r = v.validate(path: 'audio.aac', sizeBytes: okSize);
      expect(r.isOk, isFalse);
      expect(r.errorMessage, contains('не поддерживается'));
    });

    test('.opus отклоняется', () {
      expect(v.validate(path: 'song.opus', sizeBytes: okSize).isOk, isFalse);
    });

    test('файл без расширения отклоняется', () {
      expect(v.validate(path: 'noextension', sizeBytes: okSize).isOk, isFalse);
    });
  });

  group('FileValidator.validate — размер файла', () {
    test('19 МБ ровно — ok', () {
      expect(v.validate(path: 'a.mp3', sizeBytes: 19 * 1024 * 1024).isOk, isTrue);
    });

    test('20 МБ — ok (Phase 2: ограничение снято, chunking обрабатывает любой размер)', () {
      expect(v.validate(path: 'a.mp3', sizeBytes: tooBigSize).isOk, isTrue);
    });

    test('0 байт — ошибка (пустой файл недопустим)', () {
      final r = v.validate(path: 'a.mp3', sizeBytes: 0);
      expect(r.isOk, isFalse);
    });
  });
}
