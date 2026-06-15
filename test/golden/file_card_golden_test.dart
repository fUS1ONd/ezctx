// Golden на FileCard — гарантирует, что размер·длительность не обрезаются
// при длинном имени файла (issue #12). Запускать на Linux (шрифты macOS
// дают сдвиг пикселей). Мягкий допуск 5%: карточка содержит градиент и тень.
import 'dart:typed_data';

import 'package:ezctx/features/transcription/audio_metadata.dart';
import 'package:ezctx/features/transcription/selected_audio_file.dart';
import 'package:ezctx/ui/widgets/file_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Кастомный comparator с допуском (как в scroll_screens_golden_test.dart).
class TolerantGoldenComparator extends LocalFileComparator {
  TolerantGoldenComparator(Uri testFile, this.toleranceFraction)
      : super(testFile);
  final double toleranceFraction;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed) return true;
    if (result.diffPercent <= toleranceFraction) return true;
    throw FlutterError(
      result.error ??
          'golden mismatch: ${(result.diffPercent * 100).toStringAsFixed(2)}% '
              '> ${(toleranceFraction * 100).toStringAsFixed(1)}% допуска',
    );
  }
}

void _setPhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _wrap(Widget child, Brightness brightness) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: brightness),
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );

// Worst-case: длинное имя (обрежется) + длинная длительность 2:11:30 и
// размер 150.8 МБ (кейс issue #12) — должны быть видны целиком.
const _longName = '12.02 Основы Программирования (лямбда-исчисление)';
const _bigSize = 150785228; // → "150.8 МБ"

final _file = const SelectedAudioFile(
  path: '/storage/emulated/0/Recordings/$_longName.mp3',
  name: '$_longName.mp3',
  sizeBytes: _bigSize,
  extension: 'mp3',
);

const _metadata = AudioMetadata(
  name: '$_longName.mp3',
  durationSeconds: 7890, // 2:11:30
  sizeBytes: _bigSize,
);

void main() {
  late GoldenFileComparator orig;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    orig = goldenFileComparator;
  });

  setUp(() {
    final basedir = (orig as LocalFileComparator).basedir;
    // Конструктору нужен FILE URI, иначе путь к goldens смещается.
    final fakeFile = basedir.resolve('file_card_golden_test.dart');
    goldenFileComparator = TolerantGoldenComparator(fakeFile, 0.05);
  });

  tearDown(() {
    goldenFileComparator = orig;
  });

  for (final isDark in [false, true]) {
    final theme = isDark ? 'dark' : 'light';
    final brightness = isDark ? Brightness.dark : Brightness.light;

    testWidgets('FileCard_longname_$theme', (tester) async {
      _setPhoneViewport(tester);
      await tester.pumpWidget(_wrap(
        FileCard(
          file: _file,
          metadata: _metadata,
          loadingMetadata: false,
          onReplace: () {},
          onTranscribe: () {},
        ),
        brightness,
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(FileCard),
        matchesGoldenFile('goldens/FileCard_longname_$theme.png'),
      );
    });
  }
}
