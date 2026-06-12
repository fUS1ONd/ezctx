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
      // Пропускаем первое (пустое) значение, ждём второго после add().
      final future = repo.watchAll().skip(1).first;
      await repo.add(_makeEntry());
      final entries = await future;
      expect(entries, hasLength(1));
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
