import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'transcription_result.dart';

/// Сохраняет расшифровку в постоянное хранилище приложения (OUT-02).
///
/// На Android — app-specific external storage
/// (`/storage/emulated/0/Android/data/com.ezctx.app/files/transcripts`),
/// видно через USB и системный файловый менеджер.
/// На остальных платформах (или если external недоступен) — fallback на
/// `getApplicationDocumentsDirectory()`.
class TranscriptWriter {
  const TranscriptWriter();

  /// Записывает [text] в файл и возвращает абсолютный путь к нему.
  Future<String> writeTxt({
    required String baseName,
    required String text,
  }) async {
    final dir = await _resolveTranscriptsDir();
    final safeBaseName = _sanitize(baseName);
    final file = File('${dir.path}/$safeBaseName.txt');
    await file.writeAsString(text, flush: true);
    return file.path;
  }

  /// Сохраняет оба формата (plain и с таймкодами) и возвращает оба пути.
  /// Имена: `<baseName>.txt` и `<baseName>_timestamped.txt`.
  Future<({String plainPath, String timestampedPath})> writeBoth({
    required String baseName,
    required String plainText,
    required String timestampedText,
  }) async {
    final dir = await _resolveTranscriptsDir();
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
    final dir = await _resolveTranscriptsDir();
    final safe = _sanitize(baseName);
    final file = File('${dir.path}/$safe.srt');
    await file.writeAsString(_segmentsToSrt(segments), flush: true);
    return file.path;
  }

  /// Выбирает каталог для расшифровок: external (видно через USB) → fallback internal.
  ///
  /// `getExternalStorageDirectory()` возвращает null на не-Android и при
  /// отсутствии external volume; в этом случае откатываемся к внутреннему
  /// хранилищу, чтобы файлы всё равно сохранились.
  static Future<Directory> _resolveTranscriptsDir() async {
    Directory? base;
    try {
      base = await getExternalStorageDirectory();
    } catch (_) {
      base = null;
    }
    base ??= await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/transcripts');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
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
    // Ограничиваем длину: ext4 на Android допускает 255 байт,
    // оставляем запас на расширение (.srt/.txt = 4 символа) + _timestamped.txt (17).
    if (n.length > 200) n = n.substring(0, 200);
    return n;
  }
}
