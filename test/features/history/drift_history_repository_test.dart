import 'package:drift/native.dart';
import 'package:ezctx/core/database/app_database.dart';
import 'package:ezctx/features/history/drift_history_repository.dart';
import 'package:ezctx/features/history/history_entry.dart';
import 'package:ezctx/features/transcription/transcription_options.dart';
import 'package:flutter_test/flutter_test.dart';

// Вспомогательный метод для создания тестовой записи с заданными полями.
HistoryEntry _makeEntry({
  String fileName = 'lecture.mp3',
  int sizeBytes = 1024 * 1024,
  double durationSec = 60.0,
  String language = 'russian',
  String title = 'lecture',
  TranscriptionProviderId provider = TranscriptionProviderId.groq,
  bool isFavorite = false,
  String plainPath = '/data/transcripts/lecture.txt',
  String timestampedPath = '/data/transcripts/lecture_ts.txt',
  String plainText = 'Текст лекции для теста.',
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
    // In-memory БД для изолированного тестирования без файловой системы.
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftHistoryRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  // HIST-01: add() сохраняет запись; list() её возвращает.
  group('add + list', () {
    test('HIST-01: add() → list() возвращает одну запись', () async {
      await repo.add(_makeEntry());
      final entries = await repo.list();
      expect(entries, hasLength(1));
    });

    test('HIST-01: добавленная запись присутствует после list()', () async {
      await repo.add(_makeEntry(fileName: 'test.mp3'));
      final entries = await repo.list();
      expect(entries.first.fileName, equals('test.mp3'));
    });
  });

  // HIST-02: watchAll() — реактивный поток.
  group('watchAll', () {
    test('HIST-02: watchAll().first пустой при пустой БД', () async {
      // Используем take(1) чтобы получить первое значение стрима.
      final first = await repo.watchAll().first;
      expect(first, isEmpty);
    });

    test('HIST-02: watchAll() эмитит новый список после add()', () async {
      // Подписываемся на стрим до выполнения add().
      // takeWhile с условием — безопаснее skip(1).first для in-memory drift:
      // ждём первого непустого эмита или таймаут.
      final emits = <List<dynamic>>[];
      final subscription = repo.watchAll().listen(emits.add);

      // Ждём первого (пустого) эмита.
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Добавляем запись — должен прийти второй эмит.
      await repo.add(_makeEntry());

      // Ждём, пока стрим не эмитит непустой список (до 5 сек).
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (emits.isEmpty || emits.last.isEmpty) {
        if (DateTime.now().isAfter(deadline)) break;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }

      await subscription.cancel();

      // Последний эмит должен содержать одну запись.
      expect(emits.last, hasLength(1));
    });

    test('HIST-02: watchAll() эмитит пустой список после clear()', () async {
      // Добавляем запись, ждём непустого эмита, вызываем clear().
      await repo.add(_makeEntry());

      final emits = <List<dynamic>>[];
      final subscription = repo.watchAll().listen(emits.add);

      // Ждём первого (непустого) эмита.
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (emits.isEmpty || emits.last.isEmpty) {
        if (DateTime.now().isAfter(deadline)) break;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(emits.last, hasLength(1));

      // Очищаем — должен прийти пустой эмит.
      await repo.clear();
      final deadline2 = DateTime.now().add(const Duration(seconds: 5));
      while (emits.last.isNotEmpty) {
        if (DateTime.now().isAfter(deadline2)) break;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }

      await subscription.cancel();
      expect(emits.last, isEmpty);
    });
  });

  // HIST-03: полный round-trip метаданных.
  group('метаданные (HIST-03)', () {
    test('HIST-03: все метаданные сохраняются и читаются обратно', () async {
      final now = DateTime(2026, 6, 12, 14, 30);
      await repo.add(_makeEntry(
        fileName: 'лекция_биохимия.mp3',
        sizeBytes: 5 * 1024 * 1024,
        durationSec: 3600.5,
        language: 'russian',
        title: 'Биохимия — лекция 1',
        plainPath: '/data/transcripts/лекция_биохимия.txt',
        timestampedPath: '/data/transcripts/лекция_биохимия_ts.txt',
        plainText: 'Полный текст лекции по биохимии.',
        createdAt: now,
      ));

      final entry = (await repo.list()).first;
      expect(entry.fileName, equals('лекция_биохимия.mp3'));
      expect(entry.sizeBytes, equals(5 * 1024 * 1024));
      expect(entry.durationSec, equals(3600.5));
      expect(entry.language, equals('russian'));
      expect(entry.title, equals('Биохимия — лекция 1'));
      expect(entry.plainPath, equals('/data/transcripts/лекция_биохимия.txt'));
      expect(entry.timestampedPath,
          equals('/data/transcripts/лекция_биохимия_ts.txt'));
      expect(entry.plainText, equals('Полный текст лекции по биохимии.'));
      expect(entry.createdAt.millisecondsSinceEpoch,
          equals(now.millisecondsSinceEpoch));
    });
  });

  // HIST-04: round-trip провайдера (groq / deepgram).
  group('провайдер (HIST-04)', () {
    test('HIST-04: groq сохраняется и читается', () async {
      await repo.add(_makeEntry(provider: TranscriptionProviderId.groq));
      final entry = (await repo.list()).first;
      expect(entry.provider, equals(TranscriptionProviderId.groq));
    });

    test('HIST-04: deepgram сохраняется и читается', () async {
      await repo.add(_makeEntry(provider: TranscriptionProviderId.deepgram));
      final entry = (await repo.list()).first;
      expect(entry.provider, equals(TranscriptionProviderId.deepgram));
    });
  });

  // D-02: БД не дедуплицирует — два add() с одинаковым содержимым создают ДВЕ строки.
  group('дедупликация (D-02)', () {
    test('D-02: два add() с одинаковым содержимым → две строки в БД', () async {
      final entry = _makeEntry();
      await repo.add(entry);
      await repo.add(entry);
      final entries = await repo.list();
      // БД не дедуплицирует — идемпотентность обеспечивается guard'ом на UI,
      // не репозиторием.
      expect(entries, hasLength(2));
    });
  });

  // ACT-01, ACT-02: патч-обновление title и isFavorite через update().
  group('update()', () {
    test('update() меняет title, остальные поля не изменяются', () async {
      // Добавляем запись и читаем реальный id из БД.
      await repo.add(_makeEntry(
        title: 'Исходный заголовок',
        plainText: 'Исходный текст',
      ));
      final before = await repo.list();
      final realId = before.first.id;

      // Обновляем только title через copyWith.
      await repo.update(before.first.copyWith(title: 'Новый заголовок'));

      final after = await repo.list();
      expect(after.first.title, equals('Новый заголовок'));
      // plainText и другие поля не изменились.
      expect(after.first.plainText, equals('Исходный текст'));
      expect(after.first.fileName, equals(before.first.fileName));
      expect(after.first.id, equals(realId));
    });

    test('update() устанавливает isFavorite=true, остальные поля не изменяются', () async {
      // Запись с isFavorite=false по умолчанию.
      await repo.add(_makeEntry(isFavorite: false));
      final before = await repo.list();
      expect(before.first.isFavorite, isFalse);

      // Обновляем только isFavorite.
      await repo.update(before.first.copyWith(isFavorite: true));

      final after = await repo.list();
      expect(after.first.isFavorite, isTrue);
      // Остальные поля не изменились.
      expect(after.first.title, equals(before.first.title));
      expect(after.first.durationSec, equals(before.first.durationSec));
    });

    test('update() меняет title, но не трогает plainText/fileName/createdAt', () async {
      final now = DateTime(2026, 3, 15, 10, 0);
      await repo.add(_makeEntry(
        fileName: 'неизменный_файл.mp3',
        title: 'Старое имя',
        plainText: 'Расшифровка лекции.',
        createdAt: now,
      ));
      final before = await repo.list();

      await repo.update(before.first.copyWith(title: 'Новое имя'));

      final after = await repo.list();
      expect(after.first.title, equals('Новое имя'));
      expect(after.first.plainText, equals('Расшифровка лекции.'));
      expect(after.first.fileName, equals('неизменный_файл.mp3'));
      expect(
        after.first.createdAt.millisecondsSinceEpoch,
        equals(before.first.createdAt.millisecondsSinceEpoch),
      );
    });
  });

  // remove() и clear().
  group('remove + clear', () {
    test('remove() удаляет строку по id', () async {
      await repo.add(_makeEntry(fileName: 'a.mp3'));
      await repo.add(_makeEntry(fileName: 'b.mp3'));
      final before = await repo.list();
      expect(before, hasLength(2));

      // Удаляем первую запись по её id.
      await repo.remove(before.first.id);
      final after = await repo.list();
      expect(after, hasLength(1));
    });

    test('clear() удаляет все строки', () async {
      await repo.add(_makeEntry());
      await repo.add(_makeEntry());
      await repo.clear();
      final entries = await repo.list();
      expect(entries, isEmpty);
    });
  });
}
