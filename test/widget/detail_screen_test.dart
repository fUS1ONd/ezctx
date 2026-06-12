// Wave 0 скелет widget-теста detail-экрана (план 03-01).
// Стаб-репозиторий реализует весь контракт HistoryRepository (включая update()).
// Скелетные тесты помечены skip: 'Wave 2' — до появления detail_screen.dart.
// Wave 2 (план 03-02) переведёт эти тесты из RED в GREEN.
//
// import 'package:ezctx/ui/screens/detail_screen.dart'; // TODO Wave 2 — раскомментировать

import 'package:ezctx/core/providers/history_provider.dart';
import 'package:ezctx/features/history/filter_spec.dart';
import 'package:ezctx/features/history/history_entry.dart';
import 'package:ezctx/features/history/history_repository.dart';
import 'package:ezctx/features/transcription/transcription_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Стаб-репозиторий без реальной БД, с полями-шпионами для проверки вызовов.
class _StubHistoryRepository implements HistoryRepository {
  // Список вызовов update() — для проверки в тестах ACT-01, ACT-02.
  final List<HistoryEntry> updatedEntries = [];

  // Список вызовов remove() — для проверки в тестах ACT-04.
  final List<String> removedIds = [];

  final List<HistoryEntry> _entries;

  _StubHistoryRepository({List<HistoryEntry> entries = const []})
      : _entries = List.of(entries);

  @override
  Stream<List<HistoryEntry>> watchAll() => Stream.value(_entries);

  @override
  Future<List<HistoryEntry>> list() async => _entries;

  @override
  Future<void> add(HistoryEntry entry) async {}

  @override
  Future<void> remove(String id) async {
    removedIds.add(id);
  }

  @override
  Future<void> clear() async {}

  @override
  Future<void> update(HistoryEntry entry) async {
    updatedEntries.add(entry);
  }

  @override
  Stream<List<HistoryEntry>> watchSearch(FilterSpec spec) =>
      Stream.value(_entries);

  @override
  Future<List<String>> distinctLanguages() async => [];

  @override
  Future<List<String>> distinctProviders() async => [];
}

// Вспомогательная фабрика тестовой записи.
HistoryEntry _makeTestEntry({
  String id = '42',
  String title = 'Тестовая запись',
  String plainText = 'Полный текст расшифровки для тестирования detail-экрана.',
  bool isFavorite = false,
}) =>
    HistoryEntry(
      id: id,
      fileName: 'lecture.ogg',
      sizeBytes: 2 * 1024 * 1024,
      durationSec: 120.0,
      language: 'ru',
      createdAt: DateTime(2026, 3, 10, 14, 30),
      plainPath: '/data/transcripts/lecture.txt',
      timestampedPath: '/data/transcripts/lecture_ts.txt',
      title: title,
      provider: TranscriptionProviderId.groq,
      isFavorite: isFavorite,
      plainText: plainText,
    );

// Строит ProviderScope с переопределённым репозиторием.
Widget _buildApp({
  required Widget home,
  _StubHistoryRepository? stub,
}) {
  final repo = stub ?? _StubHistoryRepository();
  return ProviderScope(
    overrides: [
      historyRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      home: home,
    ),
  );
}

void main() {
  group('DetailScreen — Wave 0 скелетные тесты (ожидают detail_screen.dart)', () {
    // BRWS-03: тап по записи открывает detail-экран, показывает plainText.
    testWidgets(
      'detail_opens: detail-экран открывается и показывает plainText',
      skip: true, // Wave 2 — detail_screen.dart ещё не существует
      (tester) async {
        // TODO Wave 2: пуш на DetailScreen, проверить find.text(entry.plainText).
      },
    );

    // BRWS-03: подсветка совпадений при активном searchTerm.
    testWidgets(
      'highlight_spans: TextSpan с accent+w700 при непустом searchTerm',
      skip: true, // Wave 2 — detail_screen.dart ещё не существует
      (tester) async {
        // TODO Wave 2: передать searchTerm='текст', проверить TextSpan(fontWeight: w700).
      },
    );

    // ACT-01: тап по заголовку → TextField; submit вызывает repo.update() с новым title.
    testWidgets(
      'inline_rename: тап по заголовку → TextField, submit → repo.update()',
      skip: true, // Wave 2 — detail_screen.dart ещё не существует
      (tester) async {
        // TODO Wave 2: tap title → TextField появляется, ввести новый title,
        // submit → stub.updatedEntries.first.title == 'Новый заголовок'.
      },
    );

    // ACT-02: тап по ★ вызывает repo.update(entry.copyWith(isFavorite: true)).
    testWidgets(
      'favorite_toggle: тап по звезде → repo.update(isFavorite: true)',
      skip: true, // Wave 2 — detail_screen.dart ещё не существует
      (tester) async {
        // TODO Wave 2: tap ★ → stub.updatedEntries.first.isFavorite == true.
      },
    );

    // ACT-03: Copy → ClipboardService вызывается с plainText.
    testWidgets(
      'copy_action: Copy вызывает ClipboardService с plainText записи',
      skip: true, // Wave 2 — detail_screen.dart ещё не существует
      (tester) async {
        // TODO Wave 2: tap Copy → проверить SystemChannels.clipboard mock.
      },
    );

    // ACT-04: свайп влево на карточке → repo.remove() вызывается с entry.id.
    testWidgets(
      'swipe_delete: свайп влево → repo.remove(entry.id)',
      skip: true, // Wave 2 — detail_screen.dart ещё не существует
      (tester) async {
        // TODO Wave 2: dismiss Dismissible → stub.removedIds.contains(entry.id).
      },
    );

    // ACT-04: Delete в detail-экране → AlertDialog → confirm → repo.remove() → Navigator.pop.
    testWidgets(
      'detail_delete: Delete → AlertDialog → confirm → repo.remove() → pop',
      skip: true, // Wave 2 — detail_screen.dart ещё не существует
      (tester) async {
        // TODO Wave 2: tap Delete → AlertDialog появляется → tap Удалить
        // → stub.removedIds.contains(entry.id) && Navigator pop.
      },
    );
  });
}
