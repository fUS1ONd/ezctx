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

    final item = DataWriterItem();
    item.add(Formats.plainText(text));
    await clipboard.write([item]);
  }
}
