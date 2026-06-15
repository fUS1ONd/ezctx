import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Шеринг расшифровки как .txt-файла (а не строки текста).
///
/// Пишет свежий temp-файл в `getTemporaryDirectory()/share` и открывает
/// системный диалог «Поделиться» через [Share.shareXFiles]. Источник —
/// переданный текст текущего вида, а не сохранённые файлы (те могут быть удалены).
class ShareService {
  const ShareService();

  /// Пишет [text] во временный .txt и открывает диалог «Поделиться».
  ///
  /// [baseName] — имя исходного файла или title записи (с расширением или без).
  /// [withTimestamps] управляет суффиксом имени: true → `<имя>_timestamped.txt`,
  /// false → `<имя>.txt`. Вызывающий передаёт флаг ПО ФАКТУ контента
  /// (есть ли реально таймкоды в [text]), а не по состоянию тоггла.
  ///
  /// Бросает исключение при ошибке I/O или шеринга — вызывающий показывает snackbar.
  Future<void> shareTxt({
    required String baseName,
    required String text,
    required bool withTimestamps,
  }) async {
    final path = await writeTempTxt(baseName, text, withTimestamps);
    await Share.shareXFiles([XFile(path, mimeType: 'text/plain')]);
  }

  /// Пишет temp-файл и возвращает путь. Отделено от платформенного шеринга
  /// для unit-тестов.
  @visibleForTesting
  Future<String> writeTempTxt(
    String baseName,
    String text,
    bool withTimestamps,
  ) async {
    final base = await getTemporaryDirectory();
    final dir = Directory('${base.path}/share');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final safe = _sanitize(baseName);
    final name = withTimestamps ? '${safe}_timestamped.txt' : '$safe.txt';
    final file = File('${dir.path}/$name');
    await file.writeAsString(text, flush: true);
    return file.path;
  }

  /// Unicode-safe sanitize: сохраняет кириллицу/латиницу, вырезает только
  /// запрещённые в FS символы и управляющие.
  ///
  /// Намеренно НЕ переиспользует `TranscriptWriter._sanitize`: тот строит имя
  /// через ASCII-only `\w` и калечит кириллицу («Лекция» → «_»). Здесь имя видно
  /// пользователю в системном share-листе, поэтому кириллицу нужно сохранить.
  static String _sanitize(String name) {
    var n = name;
    final dot = n.lastIndexOf('.');
    if (dot > 0) n = n.substring(0, dot);
    // Запрещённые в FAT/NTFS/ext символы + управляющие (0x00–0x1F).
    n = n.replaceAll(RegExp(r'[/\\:*?"<>|\x00-\x1F]+'), '_').trim();
    if (n.isEmpty) n = 'transcript';
    // ext4 на Android — 255 байт; запас на суффикс _timestamped.txt (17).
    if (n.length > 200) n = n.substring(0, 200);
    return n;
  }

  /// Публичный доступ для тестов.
  @visibleForTesting
  static String sanitize(String name) => _sanitize(name);
}
