import 'dart:async';

import 'package:ezctx/core/providers/history_provider.dart';
import 'package:ezctx/features/history/history_entry.dart';
import 'package:ezctx/features/history/history_repository.dart';
import 'package:ezctx/features/transcription/result_args.dart';
import 'package:ezctx/features/transcription/selected_audio_file.dart';
import 'package:ezctx/features/transcription/transcription_options.dart';
import 'package:ezctx/features/transcription/transcription_result.dart';
import 'package:ezctx/ui/screens/result_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Тестовая заглушка HistoryRepository для перехвата вызовов add().
class _FakeHistoryRepository implements HistoryRepository {
  final List<HistoryEntry> _entries = [];
  final _controller = StreamController<List<HistoryEntry>>.broadcast();

  @override
  Stream<List<HistoryEntry>> watchAll() async* {
    yield List.unmodifiable(_entries);
    yield* _controller.stream;
  }

  @override
  Future<List<HistoryEntry>> list() async => List.unmodifiable(_entries);

  @override
  Future<void> add(HistoryEntry entry) async {
    _entries.insert(0, entry);
    _controller.add(List.unmodifiable(_entries));
  }

  @override
  Future<void> remove(String id) async {
    _entries.removeWhere((e) => e.id == id);
    _controller.add(List.unmodifiable(_entries));
  }

  @override
  Future<void> clear() async {
    _entries.clear();
    _controller.add(List.unmodifiable(_entries));
  }

  Future<void> dispose() => _controller.close();
}

void main() {
  late _FakeHistoryRepository fakeRepo;

  setUp(() {
    fakeRepo = _FakeHistoryRepository();

    // Мокируем share_plus MethodChannel — без этого ResultScreen бросает
    // MissingPluginException при didChangeDependencies (вызывает _saveTranscripts).
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/share'),
      (call) async => null,
    );
  });

  tearDown(() async {
    await fakeRepo.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/share'),
      null,
    );
  });

  // Вспомогательный метод сборки ResultScreen с переопределённым репозиторием.
  Widget buildScreen({required ResultArgs args}) {
    return ProviderScope(
      overrides: [
        historyRepositoryProvider.overrideWithValue(fakeRepo),
      ],
      child: MaterialApp(
        onGenerateRoute: (settings) => MaterialPageRoute(
          builder: (_) => const ResultScreen(),
          settings: RouteSettings(arguments: args),
        ),
      ),
    );
  }

  // D-08: provider из ResultArgs.options.model.provider корректно попадает в запись.
  // Тест RED до плана 03 (ResultArgs.options ещё не существует).
  testWidgets(
      'D-08: deepgram в ResultArgs.options → запись в репозитории с provider == deepgram',
      (tester) async {
    // ResultArgs с deepgram в options (D-08).
    // ВНИМАНИЕ: ResultArgs.options ещё не реализован (план 03) — тест
    // намеренно RED до появления этого поля.
    final args = ResultArgs(
      file: const SelectedAudioFile(
        path: '/tmp/test_deepgram.mp3',
        name: 'test_deepgram.mp3',
        sizeBytes: 2 * 1024 * 1024,
        extension: 'mp3',
      ),
      result: const TranscriptionResult(
        text: 'Тестовая расшифровка Deepgram для проверки провайдера.',
        language: 'russian',
        duration: 30.0,
        words: [],
      ),
      // options указывает deepgram — должен попасть в сохранённую запись.
      options: const TranscriptionOptions(
        model: TranscriptionModel.nova3,
        language: TranscriptionLanguage.auto,
      ),
    );

    await tester.pumpWidget(buildScreen(args: args));
    await tester.pumpAndSettle();

    // После отрисовки ResultScreen должен вызвать _saveTranscripts() → repo.add().
    // Проверяем, что добавленная запись содержит правильного провайдера.
    expect(fakeRepo._entries, hasLength(1));
    expect(
      fakeRepo._entries.first.provider,
      equals(TranscriptionProviderId.deepgram),
    );
  });
}
