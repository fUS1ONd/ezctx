import 'dart:async';
import 'dart:io';

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
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

// Заглушка path_provider — возвращает реальный tmp-каталог.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.documents);

  final String documents;

  @override
  Future<String?> getApplicationDocumentsPath() async => documents;

  @override
  Future<String?> getExternalStoragePath() async => null;
}

// Тестовая заглушка HistoryRepository для перехвата вызовов add().
class _FakeHistoryRepository implements HistoryRepository {
  final List<HistoryEntry> _entries = [];
  final _controller = StreamController<List<HistoryEntry>>.broadcast();

  // Счётчик вызовов add() — для проверки идемпотентности (D-02).
  int addCallCount = 0;

  @override
  Stream<List<HistoryEntry>> watchAll() async* {
    yield List.unmodifiable(_entries);
    yield* _controller.stream;
  }

  @override
  Future<List<HistoryEntry>> list() async => List.unmodifiable(_entries);

  @override
  Future<void> add(HistoryEntry entry) async {
    addCallCount++;
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

  @override
  Stream<List<HistoryEntry>> watchSearch(_) => const Stream.empty();

  @override
  Future<List<String>> distinctLanguages() async => [];

  @override
  Future<List<String>> distinctProviders() async => [];

  @override
  Future<void> update(HistoryEntry entry) async {}

  Future<void> dispose() => _controller.close();
}

void main() {
  late _FakeHistoryRepository fakeRepo;
  late Directory tmpDir;
  late PathProviderPlatform originalPathProvider;

  setUp(() async {
    fakeRepo = _FakeHistoryRepository();
    tmpDir = await Directory.systemTemp.createTemp('ezctx_autosave_test_');
    // Подменяем path_provider на фейковый — TranscriptWriter использует его для записи файлов.
    originalPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProvider(tmpDir.path);

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
    PathProviderPlatform.instance = originalPathProvider;
    if (await tmpDir.exists()) await tmpDir.delete(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/share'),
      null,
    );
  });

  // Полностью детерминированный прогон: всё выполняется внутри ОДНОГО
  // runAsync, чтобы реальная файловая I/O в _saveTranscripts успела
  // завершиться (вне runAsync fake-async не двигает реальные Future).
  // Затем ждём конкретный сигнал [until] (а не фиксированную паузу — она
  // была причиной flaky-падений). Между ожиданиями делаем реальный «выдох»
  // и pump, чтобы микротаски и setState отработали.
  Future<void> pumpAndAwait(
    WidgetTester tester, {
    required Widget screen,
    required Future<bool> Function() until,
  }) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(screen);
      // Прогоняем кадры route-перехода: didChangeDependencies (и
      // _saveTranscripts) срабатывает после установки маршрута, не на 1-м кадре.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await until();
      // Дренируем оставшиеся микротаски/таймеры цепочки сохранения.
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
  }

  // Универсальное детерминированное ожидание: реальный «выдох» + pump в цикле.
  Future<bool> awaitWithPump(
    WidgetTester tester,
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!condition() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await tester.pump();
    }
    return condition();
  }

  // Ждёт первый вызов add(): чередует реальный «выдох» и pump, пока сигнал
  // репозитория не сработает либо не истечёт таймаут-страховка. Возвращает
  // true, если дождались (false — таймаут; assert ниже всё равно проверит).
  Future<bool> awaitFirstAdd(WidgetTester tester) =>
      awaitWithPump(tester, () => fakeRepo.addCallCount >= 1);

  // Ждёт полного завершения _saveTranscripts для входов БЕЗ add() (пустой
  // текст): маркер «Сохранено в:». Файлы пишутся всегда (до guard'а на add),
  // поэтому появление маркера достоверно сигналит о завершении цепочки.
  Future<bool> awaitSaved(WidgetTester tester) => awaitWithPump(
      tester, () => find.text('Сохранено в:').evaluate().isNotEmpty);

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

  // Фабрика тестовых аргументов с параметризованным провайдером и текстом.
  ResultArgs makeArgs({
    TranscriptionModel model = TranscriptionModel.whisperLargeV3,
    String plainText = 'Тестовая расшифровка для проверки автозаписи.',
  }) {
    return ResultArgs(
      file: const SelectedAudioFile(
        path: '/tmp/test.mp3',
        name: 'test.mp3',
        sizeBytes: 2 * 1024 * 1024,
        extension: 'mp3',
      ),
      result: TranscriptionResult(
        text: plainText,
        language: 'russian',
        duration: 30.0,
        words: const [],
      ),
      options: TranscriptionOptions(
        model: model,
        language: TranscriptionLanguage.auto,
      ),
    );
  }

  // D-08: провайдер из ResultArgs.options.model.provider корректно попадает в запись (deepgram).
  testWidgets(
      'D-08: deepgram в ResultArgs.options → запись в репозитории с provider == deepgram',
      (tester) async {
    final args = makeArgs(model: TranscriptionModel.nova3);

    await pumpAndAwait(tester, screen: buildScreen(args: args), until: () => awaitFirstAdd(tester));

    // После отрисовки ResultScreen вызывает _saveTranscripts() → repo.add().
    expect(fakeRepo._entries, hasLength(1));
    expect(
      fakeRepo._entries.first.provider,
      equals(TranscriptionProviderId.deepgram),
    );
  });

  // D-08: аналогичная проверка для groq-провайдера.
  testWidgets(
      'D-08: groq в ResultArgs.options → запись в репозитории с provider == groq',
      (tester) async {
    final args = makeArgs(model: TranscriptionModel.whisperLargeV3);

    await pumpAndAwait(tester, screen: buildScreen(args: args), until: () => awaitFirstAdd(tester));

    expect(fakeRepo._entries, hasLength(1));
    expect(
      fakeRepo._entries.first.provider,
      equals(TranscriptionProviderId.groq),
    );
  });

  // HIST-01: после открытия экрана с непустым результатом add() вызван ровно 1 раз.
  testWidgets(
      'HIST-01: после открытия ResultScreen с непустым результатом add() вызван ровно 1 раз',
      (tester) async {
    final args = makeArgs();

    await pumpAndAwait(tester, screen: buildScreen(args: args), until: () => awaitFirstAdd(tester));

    expect(fakeRepo.addCallCount, equals(1));
  });

  // D-02: повторный pump не приводит ко второму вызову add() (идемпотентный guard).
  testWidgets(
      'D-02: повторный didChangeDependencies (re-pump) не приводит ко второму add()',
      (tester) async {
    final args = makeArgs();

    await pumpAndAwait(tester, screen: buildScreen(args: args), until: () => awaitFirstAdd(tester));

    // Повторный pump имитирует пересборку виджета.
    await tester.pump();
    await tester.pump();
    // Дополнительный реальный «выдох» — даём шанс гипотетическому второму add().
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

    // Несмотря на повторные pump, add() должен быть вызван не более 1 раза.
    expect(fakeRepo.addCallCount, equals(1));
  });

  // D-03: ResultArgs с пустым plainText → add() НЕ вызывается.
  testWidgets('D-03: ResultArgs с пустым plainText → add() не вызывается',
      (tester) async {
    final args = makeArgs(plainText: '');

    // Ждём полного завершения _saveTranscripts (маркер «Сохранено в:»),
    // чтобы ловить даже поздний ошибочный add().
    await pumpAndAwait(
      tester,
      screen: buildScreen(args: args),
      until: () => awaitSaved(tester),
    );

    expect(fakeRepo.addCallCount, equals(0));
    expect(fakeRepo._entries, isEmpty);
  });

  // D-03: whitespace-only plainText тоже не должен записываться.
  testWidgets('D-03: whitespace-only plainText → add() не вызывается',
      (tester) async {
    final args = makeArgs(plainText: '   \n  ');

    await pumpAndAwait(
      tester,
      screen: buildScreen(args: args),
      until: () => awaitSaved(tester),
    );

    expect(fakeRepo.addCallCount, equals(0));
  });
}
