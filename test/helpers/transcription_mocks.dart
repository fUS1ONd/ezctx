/// Общие тестовые моки для транскрибации.
///
/// Выделены из дублирующих определений в chunked_transcription_controller_test.dart
/// и integration_chunked_flow_test.dart — единая точка правды для всех тестов.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ezctx/core/constants/app_constants.dart';
import 'package:ezctx/features/transcription/audio_chunking_service.dart';
import 'package:ezctx/features/transcription/audio_metadata.dart';
import 'package:ezctx/features/transcription/transcription_options.dart';
import 'package:ezctx/features/transcription/transcription_provider.dart';
import 'package:ezctx/features/transcription/transcription_result.dart';

// ---------------------------------------------------------------------------
// MockTranscriptionProvider
// ---------------------------------------------------------------------------

/// Мок-провайдер транскрибации с настраиваемым обработчиком и политикой.
///
/// [concurrencyPolicy] — необязательная функция политики конкурентности.
/// Если не задана, используется дефолт Groq: `aliveKeyCount.clamp(1, kMaxConcurrentChunks)`.
///
/// [providerId] — необязательный идентификатор провайдера (дефолт `.groq`)
/// для тестирования мульти-провайдерных сценариев.
class MockTranscriptionProvider implements TranscriptionProvider {
  MockTranscriptionProvider(
    this._handler, {
    int Function(int aliveKeyCount)? concurrencyPolicy,
    TranscriptionProviderId providerId = TranscriptionProviderId.groq,
  })  : _concurrencyPolicy = concurrencyPolicy,
        _providerId = providerId;

  final Future<TranscriptionResult> Function(
    List<int> bytes,
    String filename,
    String apiKey,
  ) _handler;

  final int Function(int aliveKeyCount)? _concurrencyPolicy;
  final TranscriptionProviderId _providerId;

  /// Счётчик вызовов transcribeChunk — для проверки числа попыток в тестах.
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

  /// Политика конкурентности: если задана [concurrencyPolicy] — делегирует ей,
  /// иначе возвращает дефолт Groq: clamp(1, kMaxConcurrentChunks).
  @override
  int concurrencyFor(int aliveKeyCount) {
    if (_concurrencyPolicy != null) {
      return _concurrencyPolicy(aliveKeyCount);
    }
    return aliveKeyCount.clamp(1, AppConstants.kMaxConcurrentChunks);
  }

  @override
  TranscriptionProviderId get id => _providerId;
}

// ---------------------------------------------------------------------------
// FakeChunkFile
// ---------------------------------------------------------------------------

/// Файл-заглушка: реализует [File] без обращения к файловой системе.
/// Позволяет отслеживать вызов delete() и readAsBytes() в тестах.
class FakeChunkFile implements File {
  FakeChunkFile(this._filePath);

  final String _filePath;

  /// true, если delete() был вызван.
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

// ---------------------------------------------------------------------------
// MockAudioChunkingService
// ---------------------------------------------------------------------------

/// Мок AudioChunkingService — возвращает заданные файлы без ffmpeg.
class MockAudioChunkingService extends AudioChunkingService {
  MockAudioChunkingService({
    required this.chunkFiles,
    this.metadata = const AudioMetadata(
      name: 'test.ogg',
      durationSeconds: 2400.0,
      sizeBytes: 1024,
    ),
  });

  final List<FakeChunkFile> chunkFiles;
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
