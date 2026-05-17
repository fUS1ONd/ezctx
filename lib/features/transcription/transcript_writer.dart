import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Сохраняет расшифровку в постоянное хранилище приложения (OUT-02).
/// Путь: `<app docs>/transcripts/<baseName>.txt`
class TranscriptWriter {
  const TranscriptWriter();

  /// Записывает [text] в файл и возвращает абсолютный путь к нему.
  Future<String> writeTxt({
    required String baseName,
    required String text,
  }) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/transcripts');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final safeBaseName = _sanitize(baseName);
    final file = File('${dir.path}/$safeBaseName.txt');
    await file.writeAsString(text, flush: true);
    return file.path;
  }

  static String _sanitize(String name) {
    var n = name;
    final dotIdx = n.lastIndexOf('.');
    if (dotIdx > 0) n = n.substring(0, dotIdx);
    // Заменяем небезопасные символы (в том числе точки, которые могут создать скрытые файлы).
    n = n.replaceAll(RegExp(r'[^\w\- ]+'), '_').trim();
    // Если имя после очистки пустое — используем имя по умолчанию.
    if (n.isEmpty) n = 'transcript';
    return n;
  }
}
