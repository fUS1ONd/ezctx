// Тесты FTS5-поиска: watchSearch, фильтры, пагинация, distinct*.
// Требования: SRCH-01/02, FILT-01..06, BRWS-02, D-07.
import 'package:drift/native.dart';
import 'package:ezctx/core/database/app_database.dart';
import 'package:ezctx/features/history/drift_history_repository.dart';
import 'package:ezctx/features/history/filter_spec.dart';
import 'package:ezctx/features/history/history_entry.dart';
import 'package:ezctx/features/transcription/transcription_options.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_test/flutter_test.dart';

// Вспомогательная фабрика тестовых записей.
HistoryEntry _makeEntry({
  String fileName = 'test.mp3',
  int sizeBytes = 1024 * 1024,
  double durationSec = 60.0,
  String language = 'russian',
  String title = 'Тест',
  TranscriptionProviderId provider = TranscriptionProviderId.groq,
  bool isFavorite = false,
  String plainPath = '/data/plain.txt',
  String timestampedPath = '/data/ts.txt',
  String plainText = 'Текст теста.',
  DateTime? createdAt,
}) =>
    HistoryEntry(
      id: '',
      fileName: fileName,
      sizeBytes: sizeBytes,
      durationSec: durationSec,
      language: language,
      title: title,
      provider: provider,
      isFavorite: isFavorite,
      createdAt: createdAt ?? DateTime(2026, 1, 1, 12, 0),
      plainPath: plainPath,
      timestampedPath: timestampedPath,
      plainText: plainText,
    );

void main() {
  late AppDatabase db;
  late DriftHistoryRepository repo;

  setUp(() {
    // In-memory БД — FTS5 работает через NativeDatabase.memory().
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftHistoryRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  // SRCH-01: полнотекстовый поиск возвращает записи с совпадением.
  test('SRCH-01: watchSearch возвращает записи с совпадением в plain_text',
      () async {
    // Добавляем запись с кириллическим текстом «лекция по биохимии».
    await repo.add(_makeEntry(plainText: 'лекция по биохимии'));
    await repo.add(_makeEntry(plainText: 'семинар по физике'));

    // Prefix-поиск «лекц*» — должна вернуться только первая.
    final spec = const FilterSpec(searchTerm: 'лекц');
    final results = await repo.watchSearch(spec).first;

    expect(results, hasLength(1));
    expect(results.first.plainText, contains('лекция'));
  });

  // SRCH-02: результат поиска содержит сниппет с маркерами «».
  test('SRCH-02: watchSearch заполняет snippet с маркерами «»', () async {
    await repo.add(_makeEntry(plainText: 'лекция по биохимии'));

    final spec = const FilterSpec(searchTerm: 'лекц');
    final results = await repo.watchSearch(spec).first;

    expect(results, hasLength(1));
    // Сниппет должен присутствовать и содержать маркеры «»
    expect(results.first.snippet, isNotNull);
    expect(results.first.snippet, contains('«'));
    expect(results.first.snippet, contains('»'));
  });

  // snippet == null при пустом searchTerm.
  test('пустой searchTerm → snippet == null', () async {
    await repo.add(_makeEntry(plainText: 'лекция по биохимии'));

    final spec = const FilterSpec(); // searchTerm = ''
    final results = await repo.watchSearch(spec).first;

    expect(results, hasLength(1));
    expect(results.first.snippet, isNull);
  });

  // FILT-01: фильтр dateRange работает корректно.
  test('FILT-01: watchSearch с dateRange возвращает только записи в диапазоне',
      () async {
    final today = DateTime(2026, 6, 12);
    final yesterday = DateTime(2026, 6, 11);

    await repo.add(_makeEntry(
      plainText: 'сегодняшняя лекция',
      createdAt: today,
    ));
    await repo.add(_makeEntry(
      plainText: 'вчерашняя лекция',
      createdAt: yesterday,
    ));

    // Диапазон только сегодня.
    final spec = FilterSpec(
      dateRange: DateTimeRange(
        start: DateTime(today.year, today.month, today.day),
        end: DateTime(today.year, today.month, today.day, 23, 59, 59),
      ),
    );
    final results = await repo.watchSearch(spec).first;

    expect(results, hasLength(1));
    expect(results.first.plainText, contains('сегодняшняя'));
  });

  // FILT-04: фильтр по durationPreset работает корректно.
  test('FILT-04: durationPreset=short возвращает только записи <600 сек',
      () async {
    await repo.add(_makeEntry(durationSec: 300.0)); // короткая
    await repo.add(_makeEntry(durationSec: 1200.0)); // средняя
    await repo.add(_makeEntry(durationSec: 7200.0)); // длинная

    final spec = const FilterSpec(durationPreset: DurationPreset.short);
    final results = await repo.watchSearch(spec).first;

    expect(results, hasLength(1));
    expect(results.first.durationSec, lessThan(600));
  });

  test('FILT-04: durationPreset=medium возвращает записи BETWEEN 600 AND 3600',
      () async {
    await repo.add(_makeEntry(durationSec: 300.0));
    await repo.add(_makeEntry(durationSec: 1200.0));
    await repo.add(_makeEntry(durationSec: 7200.0));

    final spec = const FilterSpec(durationPreset: DurationPreset.medium);
    final results = await repo.watchSearch(spec).first;

    expect(results, hasLength(1));
    expect(results.first.durationSec, greaterThanOrEqualTo(600));
    expect(results.first.durationSec, lessThanOrEqualTo(3600));
  });

  test('FILT-04: durationPreset=long возвращает только записи >3600 сек',
      () async {
    await repo.add(_makeEntry(durationSec: 300.0));
    await repo.add(_makeEntry(durationSec: 1200.0));
    await repo.add(_makeEntry(durationSec: 7200.0));

    final spec = const FilterSpec(durationPreset: DurationPreset.long);
    final results = await repo.watchSearch(spec).first;

    expect(results, hasLength(1));
    expect(results.first.durationSec, greaterThan(3600));
  });

  // FILT-05: фильтр favoriteOnly работает корректно.
  test('FILT-05: watchSearch с favoriteOnly=true возвращает только избранные',
      () async {
    await repo.add(_makeEntry(isFavorite: true, plainText: 'избранная запись'));
    await repo.add(_makeEntry(isFavorite: false, plainText: 'обычная запись'));

    final spec = const FilterSpec(favoriteOnly: true);
    final results = await repo.watchSearch(spec).first;

    expect(results, hasLength(1));
    expect(results.first.isFavorite, isTrue);
  });

  // FILT-02: фильтр по языку.
  test('FILT-02: фильтр languages исключает записи другого языка', () async {
    await repo.add(_makeEntry(language: 'russian', plainText: 'русская лекция'));
    await repo.add(_makeEntry(language: 'english', plainText: 'english lecture'));

    final spec = const FilterSpec(languages: {'russian'});
    final results = await repo.watchSearch(spec).first;

    expect(results, hasLength(1));
    expect(results.first.language, equals('russian'));
  });

  // FILT-03: фильтр по провайдеру.
  test('FILT-03: фильтр providers исключает записи другого провайдера',
      () async {
    await repo.add(
      _makeEntry(
        provider: TranscriptionProviderId.groq,
        plainText: 'groq расшифровка',
      ),
    );
    await repo.add(
      _makeEntry(
        provider: TranscriptionProviderId.deepgram,
        plainText: 'deepgram расшифровка',
      ),
    );

    final spec = const FilterSpec(providers: {'groq'});
    final results = await repo.watchSearch(spec).first;

    expect(results, hasLength(1));
    expect(results.first.provider, equals(TranscriptionProviderId.groq));
  });

  // FILT-06: поиск + фильтр favoriteOnly комбинируются (intersection).
  test('FILT-06: watchSearch комбинирует searchTerm + favoriteOnly', () async {
    // Избранная запись с «лекцией»
    await repo.add(_makeEntry(
      plainText: 'лекция по химии',
      isFavorite: true,
    ));
    // Неизбранная запись с «лекцией»
    await repo.add(_makeEntry(
      plainText: 'лекция по физике',
      isFavorite: false,
    ));
    // Избранная запись без «лекции»
    await repo.add(_makeEntry(
      plainText: 'семинар по биологии',
      isFavorite: true,
    ));

    // Комбинация: поиск «лекц» + только избранные.
    final spec = const FilterSpec(
      searchTerm: 'лекц',
      favoriteOnly: true,
    );
    final results = await repo.watchSearch(spec).first;

    // Должна вернуться только «лекция по химии» (избранная + содержит «лекция»).
    expect(results, hasLength(1));
    expect(results.first.isFavorite, isTrue);
    expect(results.first.plainText, contains('химии'));
  });

  // BRWS-02: пагинация offset/limit работает корректно.
  test('BRWS-02: pageSize=2, offset=0 → первые 2 записи; offset=2 → следующие',
      () async {
    // Добавляем 4 записи с разными датами для стабильного порядка.
    for (var i = 1; i <= 4; i++) {
      await repo.add(_makeEntry(
        title: 'Запись $i',
        createdAt: DateTime(2026, 1, i, 12, 0),
      ));
    }

    // Первая страница: pageSize=2, offset=0 → 2 записи.
    final page1 = await repo
        .watchSearch(const FilterSpec(pageSize: 2, offset: 0))
        .first;
    expect(page1, hasLength(2));

    // Вторая страница: pageSize=2, offset=2 → следующие 2 записи.
    final page2 = await repo
        .watchSearch(const FilterSpec(pageSize: 2, offset: 2))
        .first;
    expect(page2, hasLength(2));

    // Страницы не пересекаются (ORDER BY desc → страница 1 содержит более поздние).
    expect(
      page1.map((e) => e.title).toSet(),
      isNot(containsAll(page2.map((e) => e.title))),
    );
  });

  // D-07: distinctLanguages возвращает только присутствующие значения.
  test('D-07: distinctLanguages возвращает только реально встречающиеся языки',
      () async {
    await repo.add(_makeEntry(language: 'russian'));
    await repo.add(_makeEntry(language: 'english'));
    await repo.add(_makeEntry(language: 'russian')); // дубль

    final langs = await repo.distinctLanguages();

    // Только уникальные, отсортированные.
    expect(langs, hasLength(2));
    expect(langs, containsAll(['english', 'russian']));
    expect(langs, equals(langs.toList()..sort())); // отсортированы
  });

  // D-07: distinctProviders возвращает только присутствующие значения.
  test('D-07: distinctProviders возвращает реально встречающихся провайдеров',
      () async {
    await repo.add(_makeEntry(provider: TranscriptionProviderId.groq));
    await repo.add(_makeEntry(provider: TranscriptionProviderId.deepgram));
    await repo.add(_makeEntry(provider: TranscriptionProviderId.groq)); // дубль

    final providers = await repo.distinctProviders();

    expect(providers, hasLength(2));
    expect(providers, containsAll(['deepgram', 'groq']));
    expect(providers, equals(providers.toList()..sort()));
  });

  // Порядок результатов: ORDER BY created_at DESC, id DESC (D-01).
  test('D-01: результаты сортируются по created_at DESC, id DESC', () async {
    final older = DateTime(2026, 1, 1);
    final newer = DateTime(2026, 6, 1);

    await repo.add(_makeEntry(title: 'Старая', createdAt: older));
    await repo.add(_makeEntry(title: 'Новая', createdAt: newer));

    final results = await repo.watchSearch(const FilterSpec()).first;

    // Более новая — первой.
    expect(results.first.title, equals('Новая'));
    expect(results.last.title, equals('Старая'));
  });
}
