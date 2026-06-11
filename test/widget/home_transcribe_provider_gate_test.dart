// test/widget/home_transcribe_provider_gate_test.dart
//
// Регрессия: pre-flight гейт «Транскрибировать» на HomeScreen должен
// проверять ключи ПРОВАЙДЕРА выбранной модели, а не жёстко Groq.
//
// Баг: при выбранной модели nova3 (Deepgram) и добавленном Deepgram-ключе
// (но без Groq-ключа) тап по «Транскрибировать» показывал диалог
// «Нужен ключ Groq» и не запускал распознавание.
import 'package:ezctx/core/providers/repository_providers.dart';
import 'package:ezctx/core/providers/service_providers.dart';
import 'package:ezctx/core/providers/theme_provider.dart';
import 'package:ezctx/core/storage/secure_storage_service.dart';
import 'package:ezctx/features/settings/api_key_repository.dart';
import 'package:ezctx/features/settings/transcription_options_repository.dart';
import 'package:ezctx/features/transcription/audio_chunking_service.dart';
import 'package:ezctx/features/transcription/audio_metadata.dart';
import 'package:ezctx/features/transcription/file_picker_service.dart';
import 'package:ezctx/features/transcription/key_pool.dart';
import 'package:ezctx/features/transcription/selected_audio_file.dart';
import 'package:ezctx/features/transcription/transcription_options.dart';
import 'package:ezctx/ui/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeThemeModeNotifier extends ThemeModeNotifier {
  @override
  ThemeMode build() => ThemeMode.light;
}

/// Picker, который сразу «выбирает» заранее заданный файл (без платформы).
class _FakePicker extends FilePickerService {
  const _FakePicker();
  @override
  Future<FilePickResult> pickAudioFile() async => const FilePickPicked(
        SelectedAudioFile(
          path: '/tmp/lecture.mp3',
          name: 'lecture.mp3',
          sizeBytes: 1024 * 1024,
          extension: 'mp3',
        ),
      );
}

/// Заглушка ffprobe: не трогаем ffmpeg_kit в widget-тесте.
class _FakeChunking extends AudioChunkingService {
  @override
  Future<AudioMetadata> getMetadata(String filePath) async =>
      throw UnimplementedError('no ffprobe in test');
}

/// In-memory хранилище ключей (изоляция per-namespace эмулируется отдельными
/// экземплярами).
class _FakeStorage implements SecureStorageService {
  _FakeStorage(this._keys);
  final List<String> _keys;

  @override
  Future<List<String>> listApiKeys() async => List.of(_keys);
  @override
  Future<void> addApiKey(String key) async => _keys.add(key);
  @override
  Future<void> removeApiKey(String key) async => _keys.remove(key);

  // ignore: deprecated_member_use_from_same_package
  @override
  Future<void> writeRawKey(String value) async {}
  // ignore: deprecated_member_use_from_same_package
  @override
  Future<String?> readRawKey() async => null;
  // ignore: deprecated_member_use_from_same_package
  @override
  Future<void> deleteRawKey() async {}
}

/// Репозиторий опций с фиксированной моделью.
class _FakeOptionsRepo extends TranscriptionOptionsRepository {
  _FakeOptionsRepo(this._options) : super();
  final TranscriptionOptions _options;
  @override
  Future<TranscriptionOptions> load() async => _options;
}

void _setPhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _wrap({
  required List<String> groqKeys,
  required List<String> deepgramKeys,
  required TranscriptionModel model,
}) {
  return ProviderScope(
    overrides: [
      themeModeProvider.overrideWith(_FakeThemeModeNotifier.new),
      groqKeyPoolProvider.overrideWithValue(KeyPool(initialKeys: const [])),
      deepgramKeyPoolProvider.overrideWithValue(KeyPool(initialKeys: const [])),
      filePickerServiceProvider.overrideWithValue(const _FakePicker()),
      audioChunkingServiceProvider.overrideWithValue(_FakeChunking()),
      apiKeyRepoProvider
          .overrideWithValue(ApiKeyRepository(_FakeStorage(groqKeys))),
      deepgramApiKeyRepoProvider
          .overrideWithValue(ApiKeyRepository(_FakeStorage(deepgramKeys))),
      transcriptionOptionsRepoProvider.overrideWithValue(
        _FakeOptionsRepo(
          TranscriptionOptions(model: model, language: TranscriptionLanguage.auto),
        ),
      ),
    ],
    child: MaterialApp(
      home: const HomeScreen(),
      routes: {
        // Поглощаем навигацию в обработку, чтобы тест не падал на отсутствии роута.
        '/processing': (_) => const Scaffold(body: Text('PROCESSING')),
      },
    ),
  );
}

Future<void> _pickAndTapTranscribe(WidgetTester tester) async {
  await tester.tap(find.text('Выберите файл'));
  await tester.pump();
  await tester.pump();
  expect(find.text('Транскрибировать'), findsOneWidget);
  await tester.tap(find.text('Транскрибировать'));
  await tester.pumpAndSettle();
}

void main() {
  group('HomeScreen transcribe gate — провайдер-aware', () {
    testWidgets(
        'nova3 + есть Deepgram-ключ, нет Groq → запускается без диалога',
        (tester) async {
      _setPhoneViewport(tester);
      await tester.pumpWidget(_wrap(
        groqKeys: const [],
        deepgramKeys: const ['dg-key-aaaaaaaaaaaaaaaaaaaa'],
        model: TranscriptionModel.nova3,
      ));
      await tester.pump();

      await _pickAndTapTranscribe(tester);

      // Диалог «Нужен ключ» не должен появиться — ключ Deepgram есть.
      expect(find.textContaining('Нужен ключ'), findsNothing);
      // Должны уйти на экран обработки.
      expect(find.text('PROCESSING'), findsOneWidget);
    });

    testWidgets('nova3 без Deepgram-ключа → диалог именно про Deepgram',
        (tester) async {
      _setPhoneViewport(tester);
      await tester.pumpWidget(_wrap(
        groqKeys: const ['groq-key-bbbbbbbbbbbbbbbbbbbb'],
        deepgramKeys: const [],
        model: TranscriptionModel.nova3,
      ));
      await tester.pump();

      await _pickAndTapTranscribe(tester);

      expect(find.text('Нужен ключ Deepgram'), findsOneWidget);
      expect(find.text('Нужен ключ Groq'), findsNothing);
    });

    testWidgets('whisper + есть Groq-ключ → запускается без диалога',
        (tester) async {
      _setPhoneViewport(tester);
      await tester.pumpWidget(_wrap(
        groqKeys: const ['groq-key-bbbbbbbbbbbbbbbbbbbb'],
        deepgramKeys: const [],
        model: TranscriptionModel.whisperLargeV3,
      ));
      await tester.pump();

      await _pickAndTapTranscribe(tester);

      expect(find.textContaining('Нужен ключ'), findsNothing);
      expect(find.text('PROCESSING'), findsOneWidget);
    });
  });
}
