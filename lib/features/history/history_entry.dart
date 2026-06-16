import 'package:flutter/foundation.dart';

import '../../core/utils/byte_format.dart';
import '../transcription/transcription_options.dart';

// Модель одной записи в истории расшифровок.
@immutable
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
    // Новые поля фазы 01 (D-08, D-09, D-05).
    required this.title,
    required this.provider,
    this.isFavorite = false,
    required this.plainText,
    this.timestampedText,
    this.snippet,
  });

  final String id;
  final String fileName;
  final int sizeBytes;
  final double durationSec;
  final String language;
  final DateTime createdAt;
  final String plainPath;
  final String timestampedPath;

  // Заголовок записи (по умолчанию — имя файла без расширения).
  final String title;

  // Провайдер транскрибации, которым создана запись (D-08).
  final TranscriptionProviderId provider;

  // Флаг избранного, по умолчанию false (D-09).
  final bool isFavorite;

  // Тело plain-текста расшифровки — источник правды для FTS5 (D-05).
  final String plainText;

  // Тело текста с таймкодами `[HH:MM:SS]`. null для старых записей (до фичи)
  // или когда таймкодов нет. Не индексируется в FTS (D1).
  final String? timestampedText;

  // Сниппет FTS5 snippet() — присутствует только при активном поиске (BRWS-01).
  // null означает: поиск неактивен или запись не содержит совпадений.
  // Поле не хранится в БД — только в результатах customSelect.
  final String? snippet;

  /// Возвращает копию записи с заменёнными полями.
  /// Незаданные параметры сохраняют значения текущего объекта.
  /// Используется для optimistic UI при переименовании (ACT-01) и
  /// тогглировании избранного (ACT-02) без перезаписи всех полей.
  HistoryEntry copyWith({
    String? id,
    String? fileName,
    int? sizeBytes,
    double? durationSec,
    String? language,
    DateTime? createdAt,
    String? plainPath,
    String? timestampedPath,
    String? title,
    TranscriptionProviderId? provider,
    bool? isFavorite,
    String? plainText,
    String? timestampedText,
    String? snippet,
  }) {
    return HistoryEntry(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      durationSec: durationSec ?? this.durationSec,
      language: language ?? this.language,
      createdAt: createdAt ?? this.createdAt,
      plainPath: plainPath ?? this.plainPath,
      timestampedPath: timestampedPath ?? this.timestampedPath,
      title: title ?? this.title,
      provider: provider ?? this.provider,
      isFavorite: isFavorite ?? this.isFavorite,
      plainText: plainText ?? this.plainText,
      timestampedText: timestampedText ?? this.timestampedText,
      snippet: snippet ?? this.snippet,
    );
  }

  String get sizeFormatted => formatBytes(sizeBytes);

  /// true, если есть осмысленная версия с таймкодами, отличная от plain (D2).
  /// Управляет видимостью переключателя «С метками / Без меток».
  bool get hasTimestamps =>
      timestampedText != null &&
      timestampedText!.isNotEmpty &&
      timestampedText != plainText;

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
    // Родительный падеж: «12 мая», «3 октября» и т.д. (WR-04).
    const months = [
      'янв.', 'февр.', 'марта', 'апр.', 'мая', 'июня',
      'июля', 'авг.', 'сент.', 'окт.', 'нояб.', 'дек.',
    ];
    return '${createdAt.day} ${months[createdAt.month - 1]} · $time';
  }
}
