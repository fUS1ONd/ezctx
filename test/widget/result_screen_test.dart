import 'dart:io';

import 'package:ezctx/core/providers/history_provider.dart';
import 'package:ezctx/core/services/clipboard_service.dart';
import 'package:ezctx/features/history/history_entry.dart';
import 'package:ezctx/features/history/history_repository.dart';
import 'package:ezctx/features/transcription/result_args.dart';
import 'package:ezctx/features/transcription/selected_audio_file.dart';
import 'package:ezctx/features/transcription/transcription_result.dart';
import 'package:ezctx/ui/screens/result_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../core/services/clipboard_service_test.mocks.dart';

// Заглушка path_provider — нужна для тестов, которые ждут autosaveFuture
// (TranscriptWriter запрашивает каталог через path_provider).
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.documents);
  final String documents;

  @override
  Future<String?> getApplicationDocumentsPath() async => documents;

  @override
  Future<String?> getExternalStoragePath() async => null;
}

// Минимальная заглушка репозитория — предотвращает обращение к реальной БД.
// Записывает добавленные записи в [added] для проверки в тестах.
class _StubHistoryRepository implements HistoryRepository {
  final List<HistoryEntry> added = [];

  @override
  Stream<List<HistoryEntry>> watchAll() => const Stream.empty();

  @override
  Future<List<HistoryEntry>> list() async => [];

  @override
  Future<void> add(HistoryEntry entry) async {
    added.add(entry);
  }

  @override
  Future<void> remove(String id) async {}

  @override
  Future<void> clear() async {}

  @override
  Stream<List<HistoryEntry>> watchSearch(_) => const Stream.empty();

  @override
  Future<List<String>> distinctLanguages() async => [];

  @override
  Future<List<String>> distinctProviders() async => [];

  @override
  Future<void> update(HistoryEntry entry) async {}
}

void main() {
  const transcriptText = 'Это тестовая расшифровка лекции для проверки буфера.';

  late MockClipboardWriter mockClipboard;

  setUp(() {
    mockClipboard = MockClipboardWriter();
    when(mockClipboard.write(any)).thenAnswer((_) async {});
    ClipboardService.clipboardOverride = mockClipboard;
    ClipboardService.simulateUnavailable = false;

    // Мокируем share_plus MethodChannel — без этого tap «Поделиться» бросает
    // MissingPluginException в тестовом окружении.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/share'),
      (call) async => null,
    );
  });

  tearDown(() {
    ClipboardService.clipboardOverride = null;
    ClipboardService.simulateUnavailable = false;
    // Сбрасываем мок share_plus после каждого теста.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/share'),
      null,
    );
  });

  ResultArgs makeArgs() => const ResultArgs(
        file: SelectedAudioFile(
          path: '/tmp/test.mp3',
          name: 'test.mp3',
          sizeBytes: 1024 * 1024,
          extension: 'mp3',
        ),
        result: TranscriptionResult(
          text: transcriptText,
          language: 'russian',
          duration: 4.2,
          words: [],
        ),
        // options: использует дефолт TranscriptionOptions.defaults() — обратная совместимость
      );

  // Фабрика для теста автозаписи timestampedText — отдельная, чтобы не ломать
  // существующие тесты (у них transcriptText без таймкодов, вид plain по умолчанию).
  ResultArgs makeArgsWithTimestamps() => const ResultArgs(
        file: SelectedAudioFile(
          path: '/tmp/test.mp3',
          name: 'test.mp3',
          sizeBytes: 1024 * 1024,
          extension: 'mp3',
        ),
        result: TranscriptionResult(
          text: '[00:00:00] Это тестовая расшифровка лекции для проверки буфера.',
          plainText: 'Это тестовая расшифровка лекции для проверки буфера.',
          language: 'russian',
          duration: 4.2,
          words: [],
        ),
      );

  // ResultScreen теперь ConsumerStatefulWidget — нужен ProviderScope.
  // Переопределяем historyRepositoryProvider на заглушку, чтобы не лезть в реальную БД.
  Widget buildScreen() => ProviderScope(
        overrides: [
          historyRepositoryProvider.overrideWithValue(_StubHistoryRepository()),
        ],
        child: MaterialApp(
          onGenerateRoute: (settings) => MaterialPageRoute(
            builder: (_) => const ResultScreen(),
            settings: RouteSettings(arguments: makeArgs()),
          ),
        ),
      );

  testWidgets('ResultScreen отображает текст расшифровки в SelectableText',
      (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text(transcriptText), findsOneWidget);
    expect(find.byType(SelectableText), findsWidgets);
  });

  testWidgets('Tap «Скопировать» вызывает ClipboardService.copyText с текстом',
      (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Скопировать'));
    await tester.pump();

    verify(mockClipboard.write(any)).called(1);

    // Даём таймеру сброса состояния завершиться
    await tester.pump(const Duration(milliseconds: 1600));
  });

  testWidgets('ResultScreen содержит кнопку «Поделиться»', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('Поделиться'), findsOneWidget);
  });

  testWidgets('После tap «Скопировать» кнопка показывает «Скопировано»',
      (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Скопировать'));
    await tester.pump(const Duration(milliseconds: 100));

    // Ищем именно кнопку (PrimaryButton), а не SnackBar
    expect(
      find.descendant(
        of: find.byType(AnimatedSwitcher),
        matching: find.text('Скопировано'),
      ),
      findsOneWidget,
    );

    // Очищаем pending timer
    await tester.pump(const Duration(milliseconds: 1600));
  });

  testWidgets('Tap «Поделиться» не бросает исключение и вызывает share_plus',
      (tester) async {
    // Устанавливаем мок, захватывающий аргументы вызова Share.share.
    String? capturedText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/share'),
      (call) async {
        // share_plus передаёт текст через поле 'text' в arguments.
        if (call.method == 'share') {
          capturedText = (call.arguments as Map?)?['text'] as String?;
        }
        return null;
      },
    );

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Поделиться'));
    await tester.pumpAndSettle();

    // Ошибок быть не должно; Share.share должен был вызваться с текстом расшифровки.
    expect(capturedText, equals(transcriptText));
  });

  testWidgets('Автозапись в историю сохраняет timestampedText (текст с метками)',
      (tester) async {
    final stub = _StubHistoryRepository();
    final originalPathProvider = PathProviderPlatform.instance;

    // Всё реальное I/O (createTemp, delete) должно быть внутри runAsync —
    // за пределами FakeAsync-зоны testWidgets; иначе Dart I/O паркует навсегда.
    await tester.runAsync(() async {
      final tmpDir =
          await Directory.systemTemp.createTemp('ezctx_ts_text_test_');
      PathProviderPlatform.instance = _FakePathProvider(tmpDir.path);

      await tester.pumpWidget(ProviderScope(
        overrides: [historyRepositoryProvider.overrideWithValue(stub)],
        child: MaterialApp(
          onGenerateRoute: (settings) => MaterialPageRoute(
            builder: (_) => const ResultScreen(),
            settings: RouteSettings(arguments: makeArgsWithTimestamps()),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Ждём завершения автозаписи через тестовый хук autosaveFuture.
      final state =
          tester.state<ResultScreenState>(find.byType(ResultScreen));
      await state.autosaveFuture;
      await tester.pump();

      await tmpDir.delete(recursive: true);
    });

    // Восстанавливаем глобальный path_provider после runAsync.
    PathProviderPlatform.instance = originalPathProvider;

    expect(stub.added, hasLength(1));
    expect(
      stub.added.first.timestampedText,
      equals('[00:00:00] Это тестовая расшифровка лекции для проверки буфера.'),
    );
    expect(stub.added.first.hasTimestamps, isTrue);
  });
}
