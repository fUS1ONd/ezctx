import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:super_clipboard/super_clipboard.dart';

import 'package:ezctx/core/services/clipboard_service.dart';

import 'clipboard_service_test.mocks.dart';

// Генерируем мок для абстрактного ClipboardWriter
@GenerateMocks([ClipboardWriter])
void main() {
  late MockClipboardWriter mockClipboard;

  setUp(() {
    mockClipboard = MockClipboardWriter();
    // Сбрасываем переопределения перед каждым тестом
    ClipboardService.clipboardOverride = null;
    ClipboardService.simulateUnavailable = false;
  });

  tearDown(() {
    // Гарантированно сбрасываем после каждого теста
    ClipboardService.clipboardOverride = null;
    ClipboardService.simulateUnavailable = false;
  });

  group('ClipboardService.copyText', () {
    // CP-02a: copyText вызывает clipboard.write с DataWriterItem содержащим plain text
    test('CP-02a: вызывает clipboard.write с DataWriterItem', () async {
      // Настраиваем мок: write ничего не бросает
      when(mockClipboard.write(any)).thenAnswer((_) async {});
      ClipboardService.clipboardOverride = mockClipboard;

      await ClipboardService.copyText('тестовая транскрипция');

      // Проверяем что write был вызван ровно один раз с каким-то списком DataWriterItem
      verify(mockClipboard.write(any)).called(1);
    });

    // CP-02b: когда Clipboard API недоступен → бросает StateError
    // simulateUnavailable имитирует случай, когда SystemClipboard.instance == null
    // (например, Firefox или неподдерживаемая платформа)
    test('CP-02b: когда clipboard недоступен → бросает StateError', () async {
      ClipboardService.simulateUnavailable = true;

      await expectLater(
        () => ClipboardService.copyText('текст'),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Clipboard API недоступен'),
        )),
      );
    });

    // CP-02c: когда clipboard.write бросает PlatformException → исключение пробрасывается
    test('CP-02c: когда clipboard.write бросает PlatformException → пробрасывается', () async {
      when(mockClipboard.write(any)).thenThrow(
        PlatformException(code: 'CLIPBOARD_ERROR', message: 'тест ошибки'),
      );
      ClipboardService.clipboardOverride = mockClipboard;

      expect(
        () => ClipboardService.copyText('текст'),
        throwsA(isA<PlatformException>()),
      );
    });
  });
}
