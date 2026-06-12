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

import '../core/services/clipboard_service_test.mocks.dart';

// Минимальная заглушка репозитория — предотвращает обращение к реальной БД.
class _StubHistoryRepository implements HistoryRepository {
  @override
  Stream<List<HistoryEntry>> watchAll() => const Stream.empty();

  @override
  Future<List<HistoryEntry>> list() async => [];

  @override
  Future<void> add(HistoryEntry entry) async {}

  @override
  Future<void> remove(String id) async {}

  @override
  Future<void> clear() async {}
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
}
