import 'package:flutter/foundation.dart';
import 'package:super_clipboard/super_clipboard.dart';

/// Сервис записи в буфер обмена через super_clipboard.
/// Обходит Android Binder-лимит (~1 MB) для длинных транскрипций.
final class ClipboardService {
  const ClipboardService._();

  /// @visibleForTesting: переопределение ClipboardWriter для тестируемости.
  /// В продакшене используется SystemClipboard.instance.
  @visibleForTesting
  static ClipboardWriter? clipboardOverride;

  /// @visibleForTesting: если true — имитирует недоступность Clipboard API (instance == null).
  @visibleForTesting
  static bool simulateUnavailable = false;

  /// Копирует [text] в системный буфер обмена.
  ///
  /// Выбрасывает [StateError], если Clipboard API недоступен на платформе.
  /// Прочие исключения (например, [PlatformException]) пробрасываются наружу.
  static Future<void> copyText(String text) async {
    final clipboard =
        simulateUnavailable ? null : (clipboardOverride ?? SystemClipboard.instance);

    if (clipboard == null) {
      throw StateError('Clipboard API недоступен на этой платформе');
    }

    // Временная диагностика issue #16: длина копируемого текста.
    // Позволяет на устройстве сопоставить обрезку буфера с реальным размером (убрать после проверки).
    debugPrint('copyText len=${text.length}');

    final item = DataWriterItem();
    // .lazy() создаёт DataRepresentation.lazy: данные отдаются нативно через ContentProvider (content-URI),
    // минуя ~1 MB Binder-лимит. Синхронный Formats.plainText(text) → DataRepresentation.simple идёт inline
    // в ClipData и потому обрезается на больших транскрипциях (issue #16).
    item.add(Formats.plainText.lazy(() => text));
    await clipboard.write([item]);
  }
}
