import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ezctx/core/constants/app_constants.dart';
import 'package:ezctx/core/error/app_exception.dart';
import 'package:ezctx/features/settings/api_key_repository.dart';
import 'package:ezctx/features/transcription/audio_chunking_service.dart';
import 'package:ezctx/features/transcription/audio_metadata.dart';
import 'package:ezctx/features/transcription/chunked_transcription_controller.dart';
import 'package:ezctx/features/transcription/groq_key_pool.dart';
import 'package:ezctx/features/transcription/normalized_audio_file.dart';
import 'package:ezctx/features/transcription/transcription_options.dart';
import 'package:ezctx/features/transcription/transcription_provider.dart';
import 'package:ezctx/features/transcription/transcription_result.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Ручные моки.
// ---------------------------------------------------------------------------

/// Мок-провайдер транскрибации с настраиваемым обработчиком.
/// Реализует [TranscriptionProvider] напрямую (без сети) — стратегия
/// `implements` работает потому, что интерфейс не содержит сетевого
/// single-shot `transcribe(...)` (см. acceptance Task 1 плана 07-02).
class _MockTranscriptionProvider implements TranscriptionProvider {
  _MockTranscriptionProvider(this._handler);

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
    TranscriptionOptions options = const TranscriptionOptions.defaults(),
  }) async {
    callCount++;
    return _handler(bytes, filename, apiKey);
  }

  @override
  int concurrencyFor(int aliveKeyCount) =>
      aliveKeyCount.clamp(1, AppConstants.kMaxConcurrentChunks);

  @override
  TranscriptionProviderId get id => TranscriptionProviderId.groq;
}

/// Файл-заглушка: реализует [File] без обращения к файловой системе.
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
  _MockAudioChunkingService({
    required this.chunkFiles,
    this.metadata = const AudioMetadata(
      name: 'test.ogg',
      durationSeconds: 2400.0,
      sizeBytes: 1024,
    ),
  });

  final List<_FakeChunkFile> chunkFiles;
  final AudioMetadata metadata;

  @override
  Future<AudioMetadata> getMetadata(String filePath) async => metadata;

  @override
  Future<List<File>> split(
    String filePath,
    double totalDurationSeconds, {
    String? outputDir,
  }) async {
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

final _dummyFile = NormalizedAudioFile(
  path: '/tmp/test_lecture.ogg',
  // 9000s = 2.5 ч → chunkDuration = 9000/2 = 4500s → offset чанка 1 = [01:15:00]
  durationSeconds: 9000.0,
);

TranscriptionResult _makeResult({
  String text = 'Привет мир',
  List<TranscriptionSegment> segments = const [],
  double duration = 60.0,
}) =>
    TranscriptionResult(
      text: text,
      language: 'ru',
      duration: duration,
      words: const [],
      segments: segments,
    );

// ---------------------------------------------------------------------------
// Тесты.
// ---------------------------------------------------------------------------

void main() {
  group('ChunkedTranscriptionController', () {
    // -----------------------------------------------------------------------
    // 1. Успешная транскрибация одного чанка.
    // -----------------------------------------------------------------------
    test('успех: один чанк → ChunkedSuccess с текстом', () async {
      final chunk = _FakeChunkFile('/tmp/chunk_000.ogg');
      final apiService = _MockTranscriptionProvider(
        (_, __, ___) async => _makeResult(text: 'Лекция по физике'),
      );
      final chunkingService = _MockAudioChunkingService(chunkFiles: [chunk]);

      final ctrl = ChunkedTranscriptionController(
        pool: GroqKeyPool(initialKeys: [_testKey.raw]),
        apiService: apiService,
        chunkingService: chunkingService,
      );

      await ctrl.start(_dummyFile);

      expect(ctrl.state, isA<ChunkedSuccess>());
      final success = ctrl.state as ChunkedSuccess;
      expect(success.result.text, contains('Лекция по физике'));
    });

    // -----------------------------------------------------------------------
    // 2. Retry на NetworkException → итог ChunkedSuccess.
    // -----------------------------------------------------------------------
    test('retry: NetworkException на первом вызове → второй вызов успешен', () async {
      final chunk = _FakeChunkFile('/tmp/chunk_000.ogg');
      int calls = 0;
      final apiService = _MockTranscriptionProvider((_, __, ___) async {
        calls++;
        if (calls == 1) throw const NetworkException('timeout');
        return _makeResult(text: 'Успех после retry');
      });
      final chunkingService = _MockAudioChunkingService(chunkFiles: [chunk]);

      final ctrl = ChunkedTranscriptionController(
        pool: GroqKeyPool(initialKeys: [_testKey.raw]),
        apiService: apiService,
        chunkingService: chunkingService,
        retryDelay: (_) => Duration.zero,
      );

      await ctrl.start(_dummyFile);

      expect(ctrl.state, isA<ChunkedSuccess>());
      expect(calls, equals(2));
    });

    // -----------------------------------------------------------------------
    // 3. AuthException — не ретраится.
    // -----------------------------------------------------------------------
    test('нет retry на AuthException: mock вызван ровно 1 раз', () async {
      final chunk = _FakeChunkFile('/tmp/chunk_000.ogg');
      final apiService = _MockTranscriptionProvider(
        (_, __, ___) async => throw const AuthException('Неверный ключ'),
      );
      final chunkingService = _MockAudioChunkingService(chunkFiles: [chunk]);

      final ctrl = ChunkedTranscriptionController(
        pool: GroqKeyPool(initialKeys: [_testKey.raw]),
        apiService: apiService,
        chunkingService: chunkingService,
      );

      await ctrl.start(_dummyFile);

      expect(ctrl.state, isA<ChunkedError>());
      final err = ctrl.state as ChunkedError;
      expect(err.retryable, isFalse);
      expect(apiService.callCount, equals(1));
    });

    // -----------------------------------------------------------------------
    // 4. Параллельность ≤ maxConcurrent.
    // -----------------------------------------------------------------------
    test('параллельность: не более maxConcurrent=2 одновременных запросов', () async {
      const maxConcurrent = 2;
      const totalChunks = 5;

      int concurrent = 0;
      int maxObservedConcurrent = 0;

      final chunks = List.generate(
        totalChunks,
        (i) => _FakeChunkFile('/tmp/chunk_${i.toString().padLeft(3, '0')}.ogg'),
      );

      final apiService = _MockTranscriptionProvider((_, __, ___) async {
        concurrent++;
        if (concurrent > maxObservedConcurrent) {
          maxObservedConcurrent = concurrent;
        }
        await Future.delayed(const Duration(milliseconds: 30));
        concurrent--;
        return _makeResult();
      });
      final chunkingService = _MockAudioChunkingService(chunkFiles: chunks);

      // 2 ключа → aliveKeyCount=2 → semaphore=min(2, kMaxConcurrentChunks)=2
      final ctrl = ChunkedTranscriptionController(
        pool: GroqKeyPool(initialKeys: [_testKey.raw, 'second-key-${_testKey.raw}']),
        apiService: apiService,
        chunkingService: chunkingService,
      );

      await ctrl.start(_dummyFile);

      expect(
        maxObservedConcurrent,
        lessThanOrEqualTo(maxConcurrent),
        reason:
            'Одновременно работало $maxObservedConcurrent, максимум должен быть ≤ $maxConcurrent',
      );
      expect(ctrl.state, isA<ChunkedSuccess>());
    });

    // -----------------------------------------------------------------------
    // 5. Сборка таймкодов.
    // -----------------------------------------------------------------------
    test('таймкоды: chunk 0 → [00:00:00], chunk 1 offset 4500s → [01:15:00]', () async {
      final chunks = [
        _FakeChunkFile('/tmp/chunk_000.ogg'),
        _FakeChunkFile('/tmp/chunk_001.ogg'),
      ];

      final seg0 = TranscriptionSegment(
        start: 0.0,
        end: 5.0,
        text: 'Начало лекции',
      );
      final seg1 = TranscriptionSegment(
        start: 0.0,
        end: 5.0,
        text: 'Продолжение',
      );
      final seg1b = TranscriptionSegment(
        start: 5.0,
        end: 10.0,
        text: 'Ещё кусок',
      );

      int callIndex = 0;
      final apiService = _MockTranscriptionProvider((_, __, ___) async {
        final i = callIndex++;
        if (i == 0) {
          return _makeResult(text: 'Начало лекции', segments: [seg0]);
        }
        return _makeResult(text: 'Продолжение', segments: [seg1, seg1b]);
      });

      final chunkingService = _MockAudioChunkingService(
        chunkFiles: chunks,
        metadata: const AudioMetadata(
          name: 'test.ogg',
          durationSeconds: 2400.0,
          sizeBytes: 1024,
        ),
      );

      final ctrl = ChunkedTranscriptionController(
        pool: GroqKeyPool(initialKeys: [_testKey.raw]),
        apiService: apiService,
        chunkingService: chunkingService,
      );

      await ctrl.start(_dummyFile);

      expect(ctrl.state, isA<ChunkedSuccess>());
      final text = (ctrl.state as ChunkedSuccess).result.text;

      expect(text, contains('[00:00:00]'));
      expect(text, contains('[01:15:00]'));
      expect(text, contains('[01:15:05]'));
    });

    // -----------------------------------------------------------------------
    // 6. Cleanup: tmp-чанки удаляются.
    // -----------------------------------------------------------------------
    test('cleanup: все tmp-чанки удалены после старта (success)', () async {
      final chunks = List.generate(
        3,
        (i) => _FakeChunkFile('/tmp/chunk_$i.ogg'),
      );

      final apiService = _MockTranscriptionProvider(
        (_, __, ___) async => _makeResult(),
      );
      final chunkingService = _MockAudioChunkingService(chunkFiles: chunks);

      final ctrl = ChunkedTranscriptionController(
        pool: GroqKeyPool(initialKeys: [_testKey.raw]),
        apiService: apiService,
        chunkingService: chunkingService,
      );

      await ctrl.start(_dummyFile);

      for (final f in chunks) {
        expect(
          f.deleted,
          isTrue,
          reason: 'Файл ${f.path} должен быть удалён',
        );
      }
    });

    // -----------------------------------------------------------------------
    // Дополнительно: ChunkedMissingKey.
    // -----------------------------------------------------------------------
    test('отсутствие ключа → ChunkedMissingKey', () async {
      final apiService = _MockTranscriptionProvider(
        (_, __, ___) async => _makeResult(),
      );
      final chunkingService = _MockAudioChunkingService(chunkFiles: []);

      final ctrl = ChunkedTranscriptionController(
        pool: GroqKeyPool(),
        apiService: apiService,
        chunkingService: chunkingService,
      );

      await ctrl.start(_dummyFile);

      expect(ctrl.state, isA<ChunkedMissingKey>());
    });
  });
}
