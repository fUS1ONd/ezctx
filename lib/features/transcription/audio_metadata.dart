import 'dart:math' as math;

/// Метаданные аудиофайла, полученные через ffprobe.
class AudioMetadata {
  final String name;

  /// Длительность в секундах (из ffprobe: ms / 1000.0).
  final double durationSeconds;

  /// Размер файла в байтах (из File.statSync().size).
  final int sizeBytes;

  const AudioMetadata({
    required this.name,
    required this.durationSeconds,
    required this.sizeBytes,
  });

  /// Форматированная длительность: "1:23:45" или "23:45".
  String get durationFormatted {
    final totalSeconds = durationSeconds.round();
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      return '$hours:$mm:$ss';
    }
    return '$mm:$ss';
  }

  /// Форматированный размер файла: "123.4 МБ" или "45.6 КБ".
  String get sizeFormatted {
    if (sizeBytes >= 1024 * 1024) {
      final mb = sizeBytes / (1024 * 1024);
      return '${mb.toStringAsFixed(1)} МБ';
    } else if (sizeBytes >= 1024) {
      final kb = sizeBytes / 1024;
      return '${kb.toStringAsFixed(1)} КБ';
    }
    return '$sizeBytes Б';
  }

  /// Количество чанков при разбивке на сегменты заданной длительности.
  int chunkCount(double chunkDurationSeconds) {
    if (chunkDurationSeconds <= 0) return 0;
    return (durationSeconds / chunkDurationSeconds).ceil();
  }
}
