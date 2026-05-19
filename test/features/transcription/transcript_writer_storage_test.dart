import 'dart:io';

import 'package:ezctx/features/transcription/transcript_writer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Bug 2: TranscriptWriter должен сохранять файлы в external storage
/// (видно через USB), а не во внутреннее хранилище приложения.
///
/// Покрытие:
///   1. Когда external storage доступен → файл пишется в external dir.
///   2. Когда external storage возвращает null (не-Android) → fallback на
///      internal documents, файл всё равно создаётся.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider({this.external, required this.documents});

  final String? external;
  final String documents;

  @override
  Future<String?> getApplicationDocumentsPath() async => documents;

  @override
  Future<String?> getExternalStoragePath() async => external;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmpRoot;
  late Directory externalDir;
  late Directory internalDir;
  late PathProviderPlatform original;

  setUp(() async {
    tmpRoot = await Directory.systemTemp.createTemp('ezctx_writer_test_');
    externalDir = await Directory('${tmpRoot.path}/external').create();
    internalDir = await Directory('${tmpRoot.path}/internal').create();
    original = PathProviderPlatform.instance;
  });

  tearDown(() async {
    PathProviderPlatform.instance = original;
    if (await tmpRoot.exists()) await tmpRoot.delete(recursive: true);
  });

  test('writeTxt: external storage доступен → файл пишется в external', () async {
    PathProviderPlatform.instance = _FakePathProvider(
      external: externalDir.path,
      documents: internalDir.path,
    );

    final path = await const TranscriptWriter().writeTxt(
      baseName: 'lecture.mp3',
      text: 'hello',
    );

    expect(path, startsWith(externalDir.path));
    expect(path, contains('/transcripts/'));
    expect(path, endsWith('lecture.txt'));
    expect(await File(path).readAsString(), 'hello');
  });

  test('writeTxt: external == null → fallback на internal documents', () async {
    PathProviderPlatform.instance = _FakePathProvider(
      external: null,
      documents: internalDir.path,
    );

    final path = await const TranscriptWriter().writeTxt(
      baseName: 'lecture.mp3',
      text: 'hello',
    );

    expect(path, startsWith(internalDir.path));
    expect(path, contains('/transcripts/'));
    expect(await File(path).readAsString(), 'hello');
  });

  test('writeTxt: throw в getExternalStorage → fallback на internal', () async {
    // Имитируем платформу, бросающую MissingPluginException
    // (например, поведение на старых Android-устройствах или эмуляторах).
    PathProviderPlatform.instance = _ThrowingPathProvider(internalDir.path);

    final path = await const TranscriptWriter().writeTxt(
      baseName: 'audio.m4a',
      text: 'x',
    );

    expect(path, startsWith(internalDir.path));
  });

  test('writeBoth: оба файла создаются в external dir', () async {
    PathProviderPlatform.instance = _FakePathProvider(
      external: externalDir.path,
      documents: internalDir.path,
    );

    final paths = await const TranscriptWriter().writeBoth(
      baseName: 'audio.wav',
      plainText: 'plain',
      timestampedText: 'ts',
    );

    expect(paths.plainPath, startsWith(externalDir.path));
    expect(paths.plainPath, endsWith('audio.txt'));
    expect(paths.timestampedPath, endsWith('audio_timestamped.txt'));
    expect(await File(paths.plainPath).readAsString(), 'plain');
    expect(await File(paths.timestampedPath).readAsString(), 'ts');
  });
}

class _ThrowingPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _ThrowingPathProvider(this.documents);

  final String documents;

  @override
  Future<String?> getApplicationDocumentsPath() async => documents;

  @override
  Future<String?> getExternalStoragePath() async =>
      throw MissingPluginException('no external storage');
}
