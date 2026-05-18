/// Интеграционный тест полного chunked-пайплайна Phase 2.
///
/// Проверяет end-to-end поток: split → transcribeChunk → assembly → ChunkedSuccess/Error.
/// Использует ручные моки без Flutter binding (чистый dart:test) для скорости.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ezctx/core/error/app_exception.dart';
import 'package:ezctx/features/settings/api_key_repository.dart';
import 'package:ezctx/features/transcription/audio_chunking_service.dart';
import 'package:ezctx/features/transcription/audio_metadata.dart';
import 'package:ezctx/features/transcription/chunked_transcription_controller.dart';
import 'package:ezctx/features/transcription/groq_api_service.dart';
import 'package:ezctx/features/transcription/groq_key_pool.dart';
import 'package:ezctx/features/transcription/selected_audio_file.dart';
import 'package:ezctx/features/transcription/transcription_result.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Ручные моки (без mockito codegen, без Flutter binding).
// ---------------------------------------------------------------------------

/// Мок GroqApiService — обработчик вызовов задаётся через конструктор.
class _MockGroqApiService extends GroqApiService {
  _MockGroqApiService(this._handler) : super();

  final Future<TranscriptionResult> Function(
    List<int> bytes,
    String filename,
    String apiKey,
  ) _handler;

  int callCount = 0;

  @override
  Future<TranscriptionResult> transcribeChunk({
    required List<int> bytes,
    required String filename,
    required String apiKey,
  }) async {
    callCount++;
    return _handler(bytes, filename, apiKey);
  }
}

/// Файл-заглушка: реализует [File] без обращения к файловой системе.
/// Позволяет отслеживать вызов delete().
class _FakeChunkFile implements File {
  _FakeChunkFile(this._filePath);

  final String _filePath;
  bool deleted = false;

  @override
  String get path => _filePath;

  @override
  Uri get uri => Uri.file(_filePath);

  @override
  bool get isAbsolute => true;

  @override
  File get absolute => this;

  @override
  Directory get parent => throw UnimplementedError();

  @override
  Future<Uint8List> readAsBytes() async => Uint8List.fromList([1, 2, 3]);

  @override
  Uint8List readAsBytesSync() => Uint8List.fromList([1, 2, 3]);

  @override
  Future<File> delete({bool recursive = false}) async {
    deleted = true;
    return this;
  }

  @override
  void deleteSync({bool recursive = false}) => deleted = true;

  @override
  Future<bool> exists() async => !deleted;

  @override
  bool existsSync() => !deleted;

  @override
  Future<int> length() async => 3;

  @override
  int lengthSync() => 3;

  @override
  Future<File> create({bool recursive = false, bool exclusive = false}) =>
      throw UnimplementedError();

  @override
  void createSync({bool recursive = false, bool exclusive = false}) =>
      throw UnimplementedError();

  @override
  Future<File> copy(String newPath) => throw UnimplementedError();

  @override
  File copySync(String newPath) => throw UnimplementedError();

  @override
  Future<DateTime> lastAccessed() => throw UnimplementedError();

  @override
  DateTime lastAccessedSync() => throw UnimplementedError();

  @override
  Future<DateTime> lastModified() => throw UnimplementedError();

  @override
  DateTime lastModifiedSync() => throw UnimplementedError();

  @override
  Future<RandomAccessFile> open({FileMode mode = FileMode.read}) =>
      throw UnimplementedError();

  @override
  Stream<List<int>> openRead([int? start, int? end]) =>
      throw UnimplementedError();

  @override
  RandomAccessFile openSync({FileMode mode = FileMode.read}) =>
      throw UnimplementedError();

  @override
  IOSink openWrite({
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<String>> readAsLines({Encoding encoding = utf8}) =>
      throw UnimplementedError();

  @override
  List<String> readAsLinesSync({Encoding encoding = utf8}) =>
      throw UnimplementedError();

  @override
  Future<String> readAsString({Encoding encoding = utf8}) =>
      throw UnimplementedError();

  @override
  String readAsStringSync({Encoding encoding = utf8}) =>
      throw UnimplementedError();

  @override
  Future<File> rename(String newPath) => throw UnimplementedError();

  @override
  File renameSync(String newPath) => throw UnimplementedError();

  @override
  Future<String> resolveSymbolicLinks() => throw UnimplementedError();

  @override
  String resolveSymbolicLinksSync() => throw UnimplementedError();

  @override
  Future setLastAccessed(DateTime time) => throw UnimplementedError();

  @override
  void setLastAccessedSync(DateTime time) => throw UnimplementedError();

  @override
  Future setLastModified(DateTime time) => throw UnimplementedError();

  @override
  void setLastModifiedSync(DateTime time) => throw UnimplementedError();

  @override
  Future<FileStat> stat() => throw UnimplementedError();

  @override
  FileStat statSync() => throw UnimplementedError();

  @override
  Stream<FileSystemEvent> watch({
    int events = FileSystemEvent.all,
    bool recursive = false,
  }) =>
      throw UnimplementedError();

  @override
  Future<File> writeAsBytes(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) =>
      throw UnimplementedError();

  @override
  void writeAsBytesSync(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) =>
      throw UnimplementedError();

  @override
  Future<File> writeAsString(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) =>
      throw UnimplementedError();

  @override
  void writeAsStringSync(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) =>
      throw UnimplementedError();
}

/// Мок AudioChunkingService — возвращает заданные файлы без ffmpeg.
class _MockAudioChunkingService extends AudioChunkingService {
  _MockAudioChunkingService({required this.chunkFiles});

  final List<_FakeChunkFile> chunkFiles;

  @override
  Future<AudioMetadata> getMetadata(String filePath) async => const AudioMetadata(
        name: 'test.mp3',
        durationSeconds: 2400.0,
        sizeBytes: 1024,
      );

  @override
  Future<List<File>> split(String filePath, {String? outputDir}) async {
    return chunkFiles;
  }
}

// ---------------------------------------------------------------------------
// Константы.
// ---------------------------------------------------------------------------

const _testKey = ApiKeyView(
  raw: 'test-api-key-1234567890',
  masked: '••••••••••••••••1234',
);

final _dummyFile = SelectedAudioFile(
  path: '/tmp/test_lecture.mp3',
  name: 'test_lecture.mp3',
  sizeBytes: 50 * 1024 * 1024, // 50 МБ — больше старого лимита 19 МБ
  extension: 'mp3',
);

// ---------------------------------------------------------------------------
// Интеграционные тесты.
// ---------------------------------------------------------------------------

void main() {
  group('Integration: ChunkedTranscriptionController — полный пайплайн', () {
    // -----------------------------------------------------------------------
    // Сценарий 1: Happy path, 2 чанка с сегментами → таймкоды в тексте.
    // -----------------------------------------------------------------------
    test('сценарий 1 — happy path 2 чанка: ChunkedSuccess, текст с таймкодами', () async {
      final chunks = [
        _FakeChunkFile('/tmp/chunk_000.mp3'),
        _FakeChunkFile('/tmp/chunk_001.mp3'),
      ];

      // Сегмент в чанке 0 (offset=0s): [00:00:00] Привет мир
      final seg0 = TranscriptionSegment(
        start: 0.0,
        end: 2.0,
        text: 'Привет мир',
      );
      // Сегмент в чанке 1 (offset=4500s): [01:15:00] Как дела
      final seg1 = TranscriptionSegment(
        start: 0.0,
        end: 1.5,
        text: 'Как дела',
      );

      int callIndex = 0;
      final apiService = _MockGroqApiService((_, __, ___) async {
        final i = callIndex++;
        if (i == 0) {
          return TranscriptionResult(
            text: 'Привет мир',
            language: 'ru',
            duration: 60.0,
            words: const [],
            segments: [seg0],
          );
        }
        return TranscriptionResult(
          text: 'Как дела',
          language: 'ru',
          duration: 60.0,
          words: const [],
          segments: [seg1],
        );
      });

      // 1 ключ → aliveKeyCount=1 → semaphore=1 → последовательное выполнение
      final ctrl = ChunkedTranscriptionController(
        pool: GroqKeyPool(initialKeys: [_testKey.raw]),
        apiService: apiService,
        chunkingService: _MockAudioChunkingService(chunkFiles: chunks),
      );

      await ctrl.start(_dummyFile);

      expect(ctrl.state, isA<ChunkedSuccess>(),
          reason: 'Ожидаем ChunkedSuccess после успешной транскрибации 2 чанков');

      final result = (ctrl.state as ChunkedSuccess).result;
      // Чанк 0: offset=0, seg.start=0 → абсолютное время 0s → [00:00:00]
      expect(result.text, contains('[00:00:00] Привет мир'),
          reason: 'Первый чанк должен иметь таймкод [00:00:00]');
      // Чанк 1: offset=4500s (75 мин), seg.start=0 → абсолютное время 4500s → [01:15:00]
      expect(result.text, contains('[01:15:00] Как дела'),
          reason: 'Второй чанк с offset 4500s должен иметь таймкод [01:15:00]');
    });

    // -----------------------------------------------------------------------
    // Сценарий 2: Retry — первый вызов NetworkException, второй успешен.
    // -----------------------------------------------------------------------
    test('сценарий 2 — retry и успех: mock вызван 2 раза, итог ChunkedSuccess', () async {
      final chunk = _FakeChunkFile('/tmp/chunk_000.mp3');

      int calls = 0;
      final apiService = _MockGroqApiService((_, __, ___) async {
        calls++;
        if (calls == 1) {
          throw const NetworkException('Нет соединения');
        }
        return TranscriptionResult(
          text: 'Текст после retry',
          language: 'ru',
          duration: 30.0,
          words: const [],
          segments: const [],
        );
      });

      final ctrl = ChunkedTranscriptionController(
        pool: GroqKeyPool(initialKeys: [_testKey.raw]),
        apiService: apiService,
        chunkingService: _MockAudioChunkingService(chunkFiles: [chunk]),
      );

      await ctrl.start(_dummyFile);

      expect(ctrl.state, isA<ChunkedSuccess>(),
          reason: 'После успешного retry итог должен быть ChunkedSuccess');
      expect(calls, equals(2),
          reason: 'transcribeChunk должен быть вызван ровно 2 раза (1 провал + 1 успех)');
    });

    // -----------------------------------------------------------------------
    // Сценарий 3: Исчерпаны retries (3 попытки) → ChunkedError.
    // -----------------------------------------------------------------------
    test('сценарий 3 — исчерпаны retries: после 3 попыток ChunkedError', () async {
      final chunk = _FakeChunkFile('/tmp/chunk_000.mp3');

      int calls = 0;
      final apiService = _MockGroqApiService((_, __, ___) async {
        calls++;
        throw const NetworkException('Сеть недоступна');
      });

      final ctrl = ChunkedTranscriptionController(
        pool: GroqKeyPool(initialKeys: [_testKey.raw]),
        apiService: apiService,
        chunkingService: _MockAudioChunkingService(chunkFiles: [chunk]),
      );

      await ctrl.start(_dummyFile);

      expect(ctrl.state, isA<ChunkedError>(),
          reason: 'После 10 безуспешных попыток должна быть ChunkedError');
      // maxAttempts=10 → 10 попыток NetworkException → rethrow
      expect(calls, equals(10),
          reason: 'transcribeChunk вызывается 10 раз до исчерпания retry');
      final err = ctrl.state as ChunkedError;
      expect(err.retryable, isTrue,
          reason: 'NetworkException → retryable=true');
    });

    // -----------------------------------------------------------------------
    // Сценарий 4: Cleanup — оба файла удалены, даже при AuthException.
    // -----------------------------------------------------------------------
    test('сценарий 4 — cleanup: оба tmp-файла удалены при AuthException', () async {
      final chunk0 = _FakeChunkFile('/tmp/chunk_000.mp3');
      final chunk1 = _FakeChunkFile('/tmp/chunk_001.mp3');

      // Первый чанк успешен, второй бросает AuthException.
      // Но из-за Future.wait параллельного выполнения поведение зависит от порядка.
      // Используем maxConcurrent=1 для последовательного выполнения: chunk0 → chunk1.
      int callIndex = 0;
      final apiService = _MockGroqApiService((_, __, ___) async {
        final i = callIndex++;
        if (i == 0) {
          return TranscriptionResult(
            text: 'Первая часть',
            language: 'ru',
            duration: 30.0,
            words: const [],
            segments: const [],
          );
        }
        // Второй чанк: AuthException → не ретраится
        throw const AuthException('Неверный API-ключ');
      });

      // 1 ключ → semaphore=1 → последовательно: chunk0 → chunk1
      final ctrl = ChunkedTranscriptionController(
        pool: GroqKeyPool(initialKeys: [_testKey.raw]),
        apiService: apiService,
        chunkingService: _MockAudioChunkingService(chunkFiles: [chunk0, chunk1]),
      );

      await ctrl.start(_dummyFile);

      expect(ctrl.state, isA<ChunkedError>(),
          reason: 'AuthException на чанке 1 → итоговое состояние ChunkedError');
      final err = ctrl.state as ChunkedError;
      expect(err.retryable, isFalse,
          reason: 'AuthException → retryable=false');

      // Cleanup: оба файла должны быть удалены в блоке finally.
      expect(chunk0.deleted, isTrue,
          reason: 'chunk_000.mp3 должен быть удалён в блоке finally');
      expect(chunk1.deleted, isTrue,
          reason: 'chunk_001.mp3 должен быть удалён в блоке finally');
    });
  });
}
