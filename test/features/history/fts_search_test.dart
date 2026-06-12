// Wave 0 stub — каркас тестов FTS5-поиска.
// GREEN-реализация в плане 02 (watchSearch в DriftHistoryRepository).
import 'package:drift/native.dart';
import 'package:ezctx/core/database/app_database.dart';
import 'package:ezctx/features/history/drift_history_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftHistoryRepository repo;

  setUp(() {
    // In-memory БД — FTS5 работает в NativeDatabase.memory().
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftHistoryRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  // SRCH-01: полнотекстовый поиск возвращает записи с совпадением.
  test(
    'SRCH-01: watchSearch возвращает записи с совпадением в plain_text',
    skip: 'GREEN в плане 02',
    () async {},
  );

  // SRCH-02: результат поиска содержит сниппет с маркерами «».
  test(
    'SRCH-02: watchSearch заполняет snippet() с маркерами «»',
    skip: 'GREEN в плане 02',
    () async {},
  );

  // FILT-01: фильтр todayOnly/dateRange работает корректно.
  test(
    'FILT-01: watchSearch с todayOnly=true возвращает только сегодняшние записи',
    skip: 'GREEN в плане 02',
    () async {},
  );

  // FILT-04: фильтр по durationPreset работает корректно.
  test(
    'FILT-04: watchSearch с durationPreset=short возвращает записи <10мин',
    skip: 'GREEN в плане 02',
    () async {},
  );

  // FILT-05: фильтр favoriteOnly работает корректно.
  test(
    'FILT-05: watchSearch с favoriteOnly=true возвращает только избранные',
    skip: 'GREEN в плане 02',
    () async {},
  );

  // FILT-06: несколько фильтров комбинируются корректно.
  test(
    'FILT-06: watchSearch комбинирует поиск + фильтры',
    skip: 'GREEN в плане 02',
    () async {},
  );

  // BRWS-02: пагинация offset/limit работает корректно.
  test(
    'BRWS-02: watchSearch применяет offset и pageSize',
    skip: 'GREEN в плане 02',
    () async {},
  );
}
