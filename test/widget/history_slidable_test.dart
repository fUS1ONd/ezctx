// Wave 0 тест-стаб для свайп-поведения карточки истории (план 04-01, Task 3).
//
// ВНИМАНИЕ: на момент создания этого файла виджет `_SlidableTile` ещё НЕ
// реализован — тест ОЖИДАЕМО красный (RED). Свайп-поведение (свайп вправо
// → toggle избранного через repo.update) реализуется в плане 04-02.
//
// Инфраструктура (_StubRepo, _FixedFilterNotifier, _buildApp, _makeEntry)
// скопирована из test/widget/history_actions_test.dart.
import 'package:ezctx/core/providers/history_provider.dart';
import 'package:ezctx/features/history/filter_notifier.dart';
import 'package:ezctx/features/history/filter_spec.dart';
import 'package:ezctx/features/history/history_entry.dart';
import 'package:ezctx/features/history/history_repository.dart';
import 'package:ezctx/features/transcription/transcription_options.dart';
import 'package:ezctx/ui/screens/history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Стаб-репозиторий со шпионами для проверки вызовов мутаций.
class _StubRepo implements HistoryRepository {
  final List<String> removedIds = [];
  final List<HistoryEntry> updatedEntries = [];
  bool clearCalled = false;

  final List<HistoryEntry> _entries;

  _StubRepo({List<HistoryEntry> entries = const []})
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
  Future<void> clear() async {
    clearCalled = true;
  }

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

// Notifier с фиксированным состоянием FilterSpec — для тестов.
class _FixedFilterNotifier extends FilterNotifier {
  final FilterSpec _fixedSpec;
  _FixedFilterNotifier(this._fixedSpec);

  @override
  FilterSpec build() => _fixedSpec;
}

// Фабрика тестовой записи.
HistoryEntry _makeEntry({
  String id = '1',
  String title = 'Тестовая запись',
  bool isFavorite = false,
}) =>
    HistoryEntry(
      id: id,
      fileName: 'test.ogg',
      sizeBytes: 1024,
      durationSec: 60.0,
      language: 'ru',
      createdAt: DateTime(2026, 1, 1, 12, 0),
      plainPath: '/tmp/test.txt',
      timestampedPath: '/tmp/test_ts.txt',
      title: title,
      provider: TranscriptionProviderId.groq,
      isFavorite: isFavorite,
      plainText: 'Тестовый текст расшифровки для history_slidable_test.',
    );

// Строит ProviderScope + MaterialApp с HistoryScreen и переопределёнными провайдерами.
Widget _buildApp({
  required _StubRepo stub,
  List<HistoryEntry>? entries,
  String searchTerm = '',
}) {
  final appEntries = entries ?? stub._entries;
  return ProviderScope(
    overrides: [
      historyRepositoryProvider.overrideWithValue(stub),
      searchResultsProvider.overrideWith(
        (ref) => Stream.value(appEntries),
      ),
      filterNotifierProvider.overrideWith(
        () => _FixedFilterNotifier(FilterSpec(searchTerm: searchTerm)),
      ),
    ],
    child: MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      home: const HistoryScreen(),
    ),
  );
}

void main() {
  group('HistoryScreen _SlidableTile — Wave 0 (RED, реализация в 04-02)', () {
    // ACT-02: свайп вправо по карточке → repo.update с isFavorite: true.
    testWidgets(
      'swipe_right_toggles_favorite: свайп вправо → repo.update(isFavorite: true)',
      (tester) async {
        final entry = _makeEntry(id: '1', isFavorite: false);
        final stub = _StubRepo(entries: [entry]);

        await tester.pumpWidget(_buildApp(stub: stub, entries: [entry]));
        await tester.pumpAndSettle();

        // Свайп вправо (startToEnd) по карточке.
        await tester.drag(find.text(entry.title), const Offset(500, 0));
        await tester.pumpAndSettle();

        // repo.update() должен быть вызван с isFavorite: true.
        expect(stub.updatedEntries, isNotEmpty);
        expect(stub.updatedEntries.first.isFavorite, isTrue);
      },
    );
  });
}
