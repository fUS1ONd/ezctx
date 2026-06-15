import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

part 'app_database.g.dart';

// Индексы для сортировки по дате и фильтрации по провайдеру (FILT-03, фаза 02).
@TableIndex(name: 'idx_transcripts_created_at', columns: {#createdAt})
@TableIndex(name: 'idx_transcripts_provider', columns: {#provider})
class Transcripts extends Table {
  // INTEGER PRIMARY KEY AUTOINCREMENT — rowid, необходимый для FTS5 external-content (D-07).
  IntColumn get id => integer().autoIncrement()();

  // Метаданные файла (HIST-03).
  TextColumn get fileName => text()();
  IntColumn get sizeBytes => integer()();
  RealColumn get durationSec => real()();
  TextColumn get language => text()();

  // Новые поля (D-08, D-09).
  TextColumn get title => text()();
  TextColumn get provider => text()(); // 'groq' | 'deepgram'
  BoolColumn get isFavorite =>
      boolean().withDefault(const Constant(false))();

  // Временная метка.
  DateTimeColumn get createdAt => dateTime()();

  // Пути к txt-файлам на диске (D-06).
  TextColumn get plainPath => text()();
  TextColumn get timestampedPath => text()();

  // Тело plain-текста — источник правды для FTS5 (D-05).
  TextColumn get plainText => text()();

  // Текст с таймкодами `[HH:MM:SS]`. nullable: старые записи (до миграции v3) → NULL.
  // В FTS не индексируется — поиск только по plain_text.
  TextColumn get timestampedText => text().nullable()();
}

@DriftDatabase(tables: [Transcripts])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          // FTS5-индекс создаётся после основных таблиц.
          await _createFts5Tables();
        },
        onUpgrade: (m, from, to) async {
          // Миграция 1→2: добавляем FTS5-индекс с backfill.
          if (from < 2) {
            await _createFts5Tables();
          }
          // Миграция 2→3: nullable-колонка с текстом таймкодов (D1).
          // FTS-триггеры завязаны только на plain_text — addColumn их не ломает.
          if (from < 3) {
            await m.addColumn(transcripts, transcripts.timestampedText);
          }
        },
      );

  // DDL FTS5-таблицы и триггеров синхронизации вынесен в отдельный метод.
  // Вызывается как при onCreate, так и при onUpgrade (from < 2).
  Future<void> _createFts5Tables() async {
    // Виртуальная таблица FTS5 с external-content из transcripts.
    // tokenize='unicode61' обязателен для корректного разбиения кириллицы.
    await customStatement(
      "CREATE VIRTUAL TABLE IF NOT EXISTS transcripts_fts "
      "USING fts5(plain_text, content='transcripts', content_rowid='id', "
      "tokenize='unicode61')",
    );
    // Backfill: индексируем уже существующие строки при миграции с v1.
    await customStatement(
      'INSERT INTO transcripts_fts(rowid, plain_text) '
      'SELECT id, plain_text FROM transcripts',
    );
    // AFTER INSERT — добавляем новые токены после вставки строки.
    await customStatement(
      'CREATE TRIGGER IF NOT EXISTS transcripts_ai '
      'AFTER INSERT ON transcripts BEGIN '
      '  INSERT INTO transcripts_fts(rowid, plain_text) '
      '  VALUES (new.id, new.plain_text); '
      'END',
    );
    // BEFORE UPDATE — удаляем старые токены ДО обновления строки.
    await customStatement(
      'CREATE TRIGGER IF NOT EXISTS transcripts_bu '
      'BEFORE UPDATE ON transcripts BEGIN '
      "  INSERT INTO transcripts_fts(transcripts_fts, rowid, plain_text) "
      "  VALUES('delete', old.id, old.plain_text); "
      'END',
    );
    // AFTER UPDATE — вставляем новые токены ПОСЛЕ обновления строки.
    await customStatement(
      'CREATE TRIGGER IF NOT EXISTS transcripts_au '
      'AFTER UPDATE ON transcripts BEGIN '
      '  INSERT INTO transcripts_fts(rowid, plain_text) '
      '  VALUES (new.id, new.plain_text); '
      'END',
    );
    // BEFORE DELETE — строго BEFORE, иначе FTS читает удалённую строку → corrupted index.
    await customStatement(
      'CREATE TRIGGER IF NOT EXISTS transcripts_bd '
      'BEFORE DELETE ON transcripts BEGIN '
      "  INSERT INTO transcripts_fts(transcripts_fts, rowid, plain_text) "
      "  VALUES('delete', old.id, old.plain_text); "
      'END',
    );
  }

  // Открывает БД на фоновом изолейте.
  // sqlite3_flutter_libs автоматически предоставляет нативную библиотеку sqlite3
  // на Android. Устанавливаем tempDirectory во избежание SQLITE_CANTOPEN на Android
  // (Android запрещает запись в /tmp).
  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dbDir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbDir.path, 'history.sqlite'));

      // Исправление для Android: sqlite3 должен писать временные файлы
      // в разрешённую директорию (не /tmp).
      if (Platform.isAndroid) {
        await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
        final cacheDir = await getTemporaryDirectory();
        sqlite3.tempDirectory = cacheDir.path;
      }

      return NativeDatabase.createInBackground(file);
    });
  }
}
