import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../transcription/transcription_options.dart';
import 'filter_spec.dart';
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
          ..orderBy([
            (t) => OrderingTerm.desc(t.createdAt),
            // Вторичный ключ: при равном createdAt (секундная точность хранения
            // DateTime) гарантирует стабильный порядок по времени вставки.
            (t) => OrderingTerm.desc(t.id),
          ]))
        .watch()
        .map((rows) => rows.map(_rowToEntry).toList());
  }

  /// Возвращает снимок всех записей, отсортированных по убыванию даты.
  @override
  Future<List<HistoryEntry>> list() async {
    final rows = await (_db.select(_db.transcripts)
          ..orderBy([
            (t) => OrderingTerm.desc(t.createdAt),
            (t) => OrderingTerm.desc(t.id),
          ]))
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
          // [Rule 1 - Bug] Передаём isFavorite явно — иначе флаг игнорируется при add().
          isFavorite: Value(entry.isFavorite),
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

  /// Параметризованный поиск с фильтрами (SRCH-01/02, FILT-01..06, BRWS-02).
  /// При активном searchTerm использует FTS5 MATCH + snippet().
  /// Сортировка: created_at DESC, id DESC (D-01 — не bm25).
  @override
  Stream<List<HistoryEntry>> watchSearch(FilterSpec spec) {
    return _buildSearchQuery(spec)
        .watch()
        .map((rows) => rows.map(_searchRowToEntry).toList());
  }

  /// Строит параметризованный SQL-запрос с учётом всех активных фильтров.
  /// Безопасность: все пользовательские значения передаются через Variable.*,
  /// не через строковую интерполяцию (T-02-04, T-02-05, ASVS V5).
  /// Только LIMIT/OFFSET — числа из internal state, интерполяция безопасна.
  Selectable<QueryRow> _buildSearchQuery(FilterSpec spec) {
    final sql = StringBuffer();
    final vars = <Variable>[];

    if (spec.searchTerm.isNotEmpty) {
      // FTS5-ветка: явный список колонок + snippet() — virtual table не поддерживает SELECT *.
      sql.write(
        'SELECT t.id, t.title, t.file_name, t.size_bytes, t.duration_sec, '
        't.language, t.provider, t.is_favorite, t.created_at, '
        't.plain_path, t.timestamped_path, t.plain_text, '
        // Маркеры «» для RichText-подсветки (D-02/D-08); 10 токенов контекста.
        "snippet(transcripts_fts, 0, '«', '»', '…', 10) AS snippet "
        'FROM transcripts_fts '
        'JOIN transcripts t ON transcripts_fts.rowid = t.id '
        'WHERE transcripts_fts MATCH ? ',
      );
      // FTS5 phrase quotes: обёртка "..." подавляет интерпретацию OR/AND/NOT как операторов.
      // Внутренние кавычки экранируются удвоением (""). Суффикс * = prefix-поиск (T-02-04).
      final escaped = spec.searchTerm.replaceAll('"', '""');
      vars.add(Variable.withString('"$escaped"*'));
    } else {
      // Обычная ветка (нет поиска): NULL вместо snippet, простой SELECT.
      sql.write('SELECT t.*, NULL AS snippet FROM transcripts t WHERE 1=1 ');
    }

    // Фильтр «только избранные» (FILT-05, D-05).
    if (spec.favoriteOnly) {
      sql.write('AND t.is_favorite = 1 ');
    }

    // Фильтр по длительности — radio-пресеты (FILT-04, D-04).
    switch (spec.durationPreset) {
      case DurationPreset.short:
        sql.write('AND t.duration_sec < 600 ');
      case DurationPreset.medium:
        sql.write('AND t.duration_sec BETWEEN 600 AND 3600 ');
      case DurationPreset.long:
        sql.write('AND t.duration_sec > 3600 ');
      case null:
        break; // без ограничения по длительности
    }

    // Фильтр по диапазону дат (FILT-01, D-06).
    // Drift хранит DateTime как unix-timestamp в СЕКУНДАХ — делим на 1000 (T-02-05).
    if (spec.dateRange != null) {
      sql.write('AND t.created_at >= ? AND t.created_at <= ? ');
      vars
        ..add(Variable.withInt(
          spec.dateRange!.start.millisecondsSinceEpoch ~/ 1000,
        ))
        ..add(Variable.withInt(
          spec.dateRange!.end.millisecondsSinceEpoch ~/ 1000,
        ));
    }

    // Фильтр по языкам (FILT-02, D-07) — IN-список через плейсхолдеры.
    if (spec.languages.isNotEmpty) {
      final placeholders = List.filled(spec.languages.length, '?').join(', ');
      sql.write('AND t.language IN ($placeholders) ');
      for (final lang in spec.languages) {
        vars.add(Variable.withString(lang));
      }
    }

    // Фильтр по провайдерам (FILT-03) — IN-список через плейсхолдеры.
    if (spec.providers.isNotEmpty) {
      final placeholders = List.filled(spec.providers.length, '?').join(', ');
      sql.write('AND t.provider IN ($placeholders) ');
      for (final provider in spec.providers) {
        vars.add(Variable.withString(provider));
      }
    }

    // Сортировка по дате (D-01): НЕ по bm25, даже при активном поиске.
    sql.write('ORDER BY t.created_at DESC, t.id DESC ');

    // Пагинация (BRWS-02): LIMIT/OFFSET — числа из internal state, не пользовательский ввод.
    sql.write('LIMIT ${spec.pageSize} OFFSET ${spec.offset}');

    // readsFrom: {transcripts} — drift переизлаёт поток при любом изменении таблицы.
    // FTS5 virtual table не регистрируется как drift-таблица — только через customSelect.
    return _db.customSelect(
      sql.toString(),
      variables: vars,
      readsFrom: {_db.transcripts},
    );
  }

  /// Маппинг строки customSelect (raw SQL) → HistoryEntry со snippet.
  /// created_at хранится как unix-timestamp в СЕКУНДАХ → умножаем на 1000 (T-02-05).
  HistoryEntry _searchRowToEntry(QueryRow row) => HistoryEntry(
        id: row.read<int>('id').toString(),
        fileName: row.read<String>('file_name'),
        sizeBytes: row.read<int>('size_bytes'),
        durationSec: row.read<double>('duration_sec'),
        language: row.read<String>('language'),
        title: row.read<String>('title'),
        // Парсим строку обратно в enum; неизвестные значения → groq (fallback).
        provider: TranscriptionProviderId.values.firstWhere(
          (p) => p.name == row.read<String>('provider'),
          orElse: () => TranscriptionProviderId.groq,
        ),
        isFavorite: row.read<bool>('is_favorite'),
        // Секунды → миллисекунды для DateTime (формат хранения drift, T-02-05).
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row.read<int>('created_at') * 1000,
        ),
        plainPath: row.read<String>('plain_path'),
        timestampedPath: row.read<String>('timestamped_path'),
        plainText: row.read<String>('plain_text'),
        // null при пустом searchTerm (обычный browse); маркеры «» при поиске (D-02).
        snippet: row.readNullable<String>('snippet'),
      );

  /// Список уникальных языков из реальных записей, отсортированных (D-07, FILT-02).
  @override
  Future<List<String>> distinctLanguages() async {
    final rows = await _db.customSelect(
      'SELECT DISTINCT language FROM transcripts ORDER BY language',
      readsFrom: {_db.transcripts},
    ).get();
    return rows.map((r) => r.read<String>('language')).toList();
  }

  /// Список уникальных провайдеров из реальных записей, отсортированных (D-07, FILT-03).
  @override
  Future<List<String>> distinctProviders() async {
    final rows = await _db.customSelect(
      'SELECT DISTINCT provider FROM transcripts ORDER BY provider',
      readsFrom: {_db.transcripts},
    ).get();
    return rows.map((r) => r.read<String>('provider')).toList();
  }

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
