// Модель одной записи в истории расшифровок.
class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.fileName,
    required this.sizeBytes,
    required this.durationSec,
    required this.language,
    required this.createdAt,
    required this.plainPath,
    required this.timestampedPath,
  });

  final String id;
  final String fileName;
  final int sizeBytes;
  final double durationSec;
  final String language;
  final DateTime createdAt;
  final String plainPath;
  final String timestampedPath;

  String get sizeFormatted {
    if (sizeBytes < 1024) return '$sizeBytes Б';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} КБ';
    return '${(sizeBytes / 1024 / 1024).toStringAsFixed(1)} МБ';
  }

  String get durationFormatted {
    final total = durationSec.toInt();
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    if (h > 0) return '$hч $mмин';
    if (m > 0) return '$mмин $sс';
    return '$sс';
  }

  /// Возвращает читаемую относительную дату («Сегодня · 14:32», «Вчера · 18:05»,
  /// «12 мая · 14:22»).
  String relativeDate(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final entryDay = DateTime(createdAt.year, createdAt.month, createdAt.day);
    final diff = today.difference(entryDay).inDays;
    final time =
        '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
    if (diff == 0) return 'Сегодня · $time';
    if (diff == 1) return 'Вчера · $time';
    if (diff < 7) return '$diff дн. назад · $time';
    const months = [
      'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
    ];
    return '${createdAt.day} ${months[createdAt.month - 1]} · $time';
  }
}
