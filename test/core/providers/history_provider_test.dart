// Тесты композиции historyPageProvider/searchResultsProvider (фикс бага #1, BRWS-02).
// Спека: docs/superpowers/specs/2026-06-13-history-pagination-collapse-design.md
//
// _PagedStubRepository — по одному StreamController на offset (страницу),
// имитирует реактивные постраничные запросы drift без реальной БД.
import 'dart:async';

import 'package:ezctx/core/providers/history_provider.dart';
import 'package:ezctx/features/history/filter_notifier.dart';
import 'package:ezctx/features/history/filter_spec.dart';
import 'package:ezctx/features/history/history_entry.dart';
import 'package:ezctx/features/history/history_repository.dart';
import 'package:ezctx/features/transcription/transcription_options.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _PagedStubRepository implements HistoryRepository {
  final Map<int, StreamController<List<HistoryEntry>>> _controllers = {};

  StreamController<List<HistoryEntry>> controllerFor(int offset) =>
      _controllers.putIfAbsent(
        offset,
        () => StreamController<List<HistoryEntry>>(),
      );

  @override
  Stream<List<HistoryEntry>> watchSearch(FilterSpec spec) =>
      controllerFor(spec.offset).stream;

  @override
  Stream<List<HistoryEntry>> watchAll() => throw UnimplementedError();

  @override
  Future<List<HistoryEntry>> list() async => [];

  @override
  Future<void> add(HistoryEntry entry) async {}

  @override
  Future<void> remove(String id) async {}

  @override
  Future<void> clear() async {}

  @override
  Future<List<String>> distinctLanguages() async => [];

  @override
  Future<List<String>> distinctProviders() async => [];

  @override
  Future<void> update(HistoryEntry entry) async {}
}

HistoryEntry _makeEntry(String id, {bool isFavorite = false}) => HistoryEntry(
      id: id,
      fileName: '$id.ogg',
      sizeBytes: 1024,
      durationSec: 60.0,
      language: 'ru',
      createdAt: DateTime(2026, 1, 1, 12, 0),
      plainPath: '/tmp/$id.txt',
      timestampedPath: '/tmp/${id}_ts.txt',
      title: 'Запись $id',
      provider: TranscriptionProviderId.groq,
      isFavorite: isFavorite,
      plainText: 'Текст $id',
    );

void main() {
  late _PagedStubRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = _PagedStubRepository();
    container = ProviderContainer(overrides: [
      historyRepositoryProvider.overrideWithValue(repo),
    ]);
  });

  tearDown(() => container.dispose());

  test('после loadMore() итоговый список дополняется, а не заменяется',
      () async {
    final pageSize = container.read(filterNotifierProvider).pageSize;
    final entryA = _makeEntry('a');
    final entryB = _makeEntry('b');

    container.listen(searchResultsProvider, (_, __) {});
    repo.controllerFor(0).add([entryA]);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(searchResultsProvider).valueOrNull, [entryA]);

    repo.controllerFor(pageSize).add([entryB]);
    container.read(filterNotifierProvider.notifier).loadMore();
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(searchResultsProvider).valueOrNull,
      [entryA, entryB],
    );
  });

  test(
      'изменение записи на загруженной ранее странице не теряет записи '
      'других страниц', () async {
    final pageSize = container.read(filterNotifierProvider).pageSize;
    final entryA = _makeEntry('a');
    final entryB = _makeEntry('b');

    container.listen(searchResultsProvider, (_, __) {});
    repo.controllerFor(0).add([entryA]);
    repo.controllerFor(pageSize).add([entryB]);
    container.read(filterNotifierProvider.notifier).loadMore();
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(searchResultsProvider).valueOrNull,
      [entryA, entryB],
    );

    final entryAFav = entryA.copyWith(isFavorite: true);
    repo.controllerFor(0).add([entryAFav]);
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(searchResultsProvider).valueOrNull,
      [entryAFav, entryB],
    );
  });
}
