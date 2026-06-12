import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../transcription/transcription_options.dart';
import 'history_entry.dart';
import 'history_repository.dart';

/// Реализация HistoryRepository поверх drift/SQLite (AppDatabase).
/// Все операции чтения/записи выполняются через типизированный drift API
/// без прямого SQL — SQL-инъекции исключены (T-01-04).
class DriftHistoryRepository implements HistoryRepository {
  DriftHistoryRepository(this._db);

  final AppDatabase _db;

  /// Реактивный поток всех записей, отсортированных по убыванию даты (HIST-02).
  /// Drift автоматически эмитит новый список при любом INSERT/UPDATE/DELETE.
  @override
  Stream<List<HistoryEntry>> watchAll() {
    return (_db.select(_db.transcripts)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch()
        .map((rows) => rows.map(_rowToEntry).toList());
  }

  /// Возвращает снимок всех записей, отсортированных по убыванию даты.
  @override
  Future<List<HistoryEntry>> list() async {
    final rows = await (_db.select(_db.transcripts)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    return rows.map(_rowToEntry).toList();
  }

  /// Добавляет новую запись в БД.
  /// entry.id игнорируется — autoincrement INTEGER PRIMARY KEY присваивается самой БД (D-07).
  /// isFavorite не передаётся — используется дефолт false из схемы таблицы (D-09).
  @override
  Future<void> add(HistoryEntry entry) => _db.into(_db.transcripts).insert(
        TranscriptsCompanion.insert(
          fileName: entry.fileName,
          sizeBytes: entry.sizeBytes,
          durationSec: entry.durationSec,
          language: entry.language,
          title: entry.title,
          // Сохраняем имя enum (строку 'groq' | 'deepgram') для HIST-04 и FILT-03.
          provider: entry.provider.name,
          createdAt: entry.createdAt,
          plainPath: entry.plainPath,
          timestampedPath: entry.timestampedPath,
          plainText: entry.plainText,
        ),
      );

  /// Удаляет запись по строковому id (int.parse безопасен: id формируется самим репо).
  @override
  Future<void> remove(String id) => (_db.delete(_db.transcripts)
        ..where((t) => t.id.equals(int.parse(id))))
      .go();

  /// Очищает всю историю.
  @override
  Future<void> clear() => _db.delete(_db.transcripts).go();

  // Маппинг drift row → HistoryEntry.
  HistoryEntry _rowToEntry(Transcript row) => HistoryEntry(
        // id хранится как autoincrement INTEGER, в HistoryEntry — строковое представление.
        id: row.id.toString(),
        fileName: row.fileName,
        sizeBytes: row.sizeBytes,
        durationSec: row.durationSec,
        language: row.language,
        title: row.title,
        // Парсим строку обратно в enum; неизвестные значения → groq (fallback).
        provider: TranscriptionProviderId.values.firstWhere(
          (p) => p.name == row.provider,
          orElse: () => TranscriptionProviderId.groq,
        ),
        isFavorite: row.isFavorite,
        createdAt: row.createdAt,
        plainPath: row.plainPath,
        timestampedPath: row.timestampedPath,
        plainText: row.plainText,
      );
}
