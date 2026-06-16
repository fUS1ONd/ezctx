import 'dart:io';

import 'package:ezctx/core/services/share_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

// Заглушка path_provider: ShareService пишет в getTemporaryDirectory().
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.temp);
  final String temp;

  @override
  Future<String?> getTemporaryPath() async => temp;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ShareService.sanitize', () {
    test('сохраняет кириллицу и отрезает расширение', () {
      expect(ShareService.sanitize('Лекция 5 экзамен.m4a'), 'Лекция 5 экзамен');
    });

    test('точка в дате не считается расширением (регрессия: 14.05 ОП)', () {
      // title из истории приходит уже без расширения; точка в «14.05» —
      // часть даты, а не разделитель расширения. Раньше резалось до «14».
      expect(ShareService.sanitize('14.05 ОП'), '14.05 ОП');
    });

    test('вырезает запрещённые в FS символы', () {
      expect(ShareService.sanitize('a/b:c'), 'a_b_c');
    });

    test('пустое после очистки имя → transcript', () {
      // Строка из пробелов: trim() даёт '' → срабатывает fallback.
      // (NB: '???' схлопнулось бы в один '_' — НЕ пустой, fallback не сработает;
      // если когда-нибудь захочется чтобы и такое падало в transcript — это
      // правка impl, а не теста.)
      expect(ShareService.sanitize('   '), 'transcript');
    });
  });

  group('ShareService temp-файл', () {
    late Directory tmp;
    late PathProviderPlatform original;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('share_service_test');
      original = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _FakePathProvider(tmp.path);
    });

    tearDown(() {
      PathProviderPlatform.instance = original;
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('plain → <имя>.txt с правильным контентом', () async {
      final path =
          await const ShareService().writeTempTxt('Лекция', 'привет мир', false);
      expect(path, endsWith('/share/Лекция.txt'));
      expect(await File(path).readAsString(), 'привет мир');
    });

    test('withTimestamps → суффикс _timestamped', () async {
      final path = await const ShareService()
          .writeTempTxt('Лекция', '[00:00:00] привет', true);
      expect(path, endsWith('/share/Лекция_timestamped.txt'));
    });

    test('shareTxt вызывает канал shareFiles с text/plain и путём к файлу',
        () async {
      List<dynamic>? capturedPaths;
      List<dynamic>? capturedMimes;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/share'),
        (call) async {
          if (call.method == 'shareFiles') {
            final args = call.arguments as Map;
            capturedPaths = args['paths'] as List<dynamic>?;
            capturedMimes = args['mimeTypes'] as List<dynamic>?;
          }
          return null; // пакет подставит fallback-строку статуса
        },
      );

      await const ShareService()
          .shareTxt(baseName: 'Лекция', text: 'привет', withTimestamps: false);

      expect(capturedPaths, isNotNull);
      expect(capturedPaths!.single, endsWith('/share/Лекция.txt'));
      expect(capturedMimes!.single, 'text/plain');
      expect(
        await File(capturedPaths!.single as String).readAsString(),
        'привет',
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/share'),
        null,
      );
    });
  });
}
