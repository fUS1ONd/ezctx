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
}

@DriftDatabase(tables: [Transcripts])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async => m.createAll(),
      );

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
