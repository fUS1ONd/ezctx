import 'package:ezctx/features/transcription/result_args.dart';
import 'package:ezctx/features/transcription/selected_audio_file.dart';
import 'package:ezctx/features/transcription/transcription_result.dart';
import 'package:ezctx/ui/screens/result_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const transcriptText = 'Это тестовая расшифровка лекции для проверки буфера.';

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

  testWidgets('Tap «Скопировать» вызывает Clipboard.setData с текстом',
      (tester) async {
    String? capturedText;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        capturedText = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Скопировать'));
    await tester.pump();

    expect(capturedText, transcriptText);

    // Даём таймеру сброса состояния завершиться
    await tester.pump(const Duration(milliseconds: 1600));
  });

  testWidgets('После tap «Скопировать» кнопка показывает «Скопировано»',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);

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
