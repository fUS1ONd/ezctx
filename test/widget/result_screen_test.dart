import 'package:ezctx/core/services/clipboard_service.dart';
import 'package:ezctx/features/transcription/result_args.dart';
import 'package:ezctx/features/transcription/selected_audio_file.dart';
import 'package:ezctx/features/transcription/transcription_result.dart';
import 'package:ezctx/ui/screens/result_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../core/services/clipboard_service_test.mocks.dart';

void main() {
  const transcriptText = 'Это тестовая расшифровка лекции для проверки буфера.';

  late MockClipboardWriter mockClipboard;

  setUp(() {
    mockClipboard = MockClipboardWriter();
    when(mockClipboard.write(any)).thenAnswer((_) async {});
    ClipboardService.clipboardOverride = mockClipboard;
    ClipboardService.simulateUnavailable = false;
  });

  tearDown(() {
    ClipboardService.clipboardOverride = null;
    ClipboardService.simulateUnavailable = false;
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
      );

  Widget buildScreen() => MaterialApp(
        onGenerateRoute: (settings) => MaterialPageRoute(
          builder: (_) => const ResultScreen(),
          settings: RouteSettings(arguments: makeArgs()),
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
}
