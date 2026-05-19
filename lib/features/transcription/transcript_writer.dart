import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'transcription_result.dart';

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

  /// Генерирует SRT-субтитры из сегментов. Возвращает путь к файлу или null если segments пуст.
  Future<String?> writeSrt({
    required String baseName,
    required List<TranscriptionSegment> segments,
  }) async {
    if (segments.isEmpty) return null;
    final dir = await getApplicationDocumentsDirectory();
    final transcripts = Directory('${dir.path}/transcripts');
    if (!await transcripts.exists()) await transcripts.create(recursive: true);
    final safe = _sanitize(baseName);
    final file = File('${transcripts.path}/$safe.srt');
    await file.writeAsString(_segmentsToSrt(segments), flush: true);
    return file.path;
  }

  /// Публичный доступ для тестов.
  @visibleForTesting
  static String segmentsToSrt(List<TranscriptionSegment> segments) =>
      _segmentsToSrt(segments);

  static String _segmentsToSrt(List<TranscriptionSegment> segments) {
    final buf = StringBuffer();
    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      buf.write('${i + 1}\n');
      buf.write('${_srtTime(seg.start)} --> ${_srtTime(seg.end)}\n');
      buf.write('${seg.text.trim()}\n\n');
    }
    return buf.toString();
  }

  /// Публичный доступ для тестов.
  @visibleForTesting
  static String srtTime(double totalSeconds) => _srtTime(totalSeconds);

  /// Форматирует секунды в строку SRT-формата `HH:MM:SS,mmm`.
  /// НЕ использует Duration.toString() — тот даёт точку вместо запятой.
  /// Отрицательные значения зажимаются до нуля (защита от шума Groq/смещения чанка).
  static String _srtTime(double totalSeconds) {
    final ms = (totalSeconds.clamp(0.0, double.infinity) * 1000).round();
    final h = ms ~/ 3600000;
    final m = (ms % 3600000) ~/ 60000;
    final s = (ms % 60000) ~/ 1000;
    final millis = ms % 1000;
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')},'
        '${millis.toString().padLeft(3, '0')}';
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
