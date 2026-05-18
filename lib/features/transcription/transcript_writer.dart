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

  /// Сохраняет оба формата (plain и с таймкодами) и возвращает оба пути.
  /// Пути: `<app docs>/transcripts/<baseName>.txt` и `<baseName>_timestamped.txt`.
  Future<({String plainPath, String timestampedPath})> writeBoth({
    required String baseName,
    required String plainText,
    required String timestampedText,
  }) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/transcripts');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final safe = _sanitize(baseName);
    final plainFile = File('${dir.path}/$safe.txt');
    final tsFile = File('${dir.path}/${safe}_timestamped.txt');
    await plainFile.writeAsString(plainText, flush: true);
    await tsFile.writeAsString(timestampedText, flush: true);
    return (plainPath: plainFile.path, timestampedPath: tsFile.path);
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
