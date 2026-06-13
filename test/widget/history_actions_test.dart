// Widget-тесты действий на карточках history_screen (план 03-03, Wave 3).
// Стаб-репозиторий со шпионами: removedIds, updatedEntries, clearCalled.
// Проверяет: свайп-удаление, onTap навигацию, overflow «Очистить историю».
import 'package:ezctx/core/constants/app_constants.dart';
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
      isFavorite: false,
      plainText: 'Тестовый текст расшифровки для history_actions_test.',
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
      // MaterialApp.onGenerateRoute не нужен для базовых тестов —
      // Navigator.pushNamed вернёт null и ничего не произойдёт в тесте.
      // Для теста onTap используем NavigatorObserver.
      home: const HistoryScreen(),
    ),
  );
}

void main() {
  group('HistoryScreen actions — Wave 3', () {
    // D-01/D-02: свайп влево фиксирует панель удаления; удаление — по тапу на панель.
    testWidgets(
      'swipe_dismiss: свайп влево фиксирует панель, тап по панели → repo.remove(entry.id)',
      (tester) async {
        final entry = _makeEntry(id: '77');
        final stub = _StubRepo(entries: [entry]);

        await tester.pumpWidget(_buildApp(stub: stub, entries: [entry]));
        await tester.pumpAndSettle();

        // Находим карточку по тексту заголовка.
        expect(find.text('Тестовая запись'), findsOneWidget);

        // Свайп влево (справа налево) фиксирует красную панель удаления (D-01/D-02).
        await tester.drag(find.text('Тестовая запись'), const Offset(-500, 0));
        await tester.pumpAndSettle();

        // repo.remove() пока НЕ вызван — нужен явный тап по панели.
        expect(stub.removedIds, isEmpty);

        // Тап по панели удаления (Semantics: «Удалить запись»).
        await tester.tap(find.bySemanticsLabel('Удалить запись'));
        await tester.pumpAndSettle();

        // repo.remove() должен быть вызван с id = '77'.
        expect(stub.removedIds, contains('77'));
      },
    );

    // BRWS-03: тап по карточке — Navigator получает pushNamed с routeHistoryDetail.
    testWidgets(
      'tap_navigates_detail: тап по карточке → pushNamed routeHistoryDetail',
      (tester) async {
        final entry = _makeEntry(id: '42');
        final stub = _StubRepo(entries: [entry]);

        // Используем NavigatorObserver для перехвата навигации.
        final observer = _TestNavigatorObserver();

        await tester.pumpWidget(ProviderScope(
          overrides: [
            historyRepositoryProvider.overrideWithValue(stub),
            searchResultsProvider.overrideWith(
              (ref) => Stream.value([entry]),
            ),
            filterNotifierProvider.overrideWith(
              () => _FixedFilterNotifier(const FilterSpec()),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
              useMaterial3: true,
            ),
            navigatorObservers: [observer],
            // onGenerateRoute нужен чтобы pushNamed не бросил исключение.
            // settings передаётся в MaterialPageRoute — observer получит route.settings.name.
            onGenerateRoute: (settings) {
              if (settings.name == AppConstants.routeHistoryDetail) {
                return MaterialPageRoute(
                  settings: settings, // обязательно для корректного settings.name
                  builder: (_) => const Scaffold(
                    body: Text('DetailScreen stub'),
                  ),
                );
              }
              return null;
            },
            home: const HistoryScreen(),
          ),
        ));
        await tester.pumpAndSettle();

        // Тап по карточке.
        await tester.tap(find.text('Тестовая запись'));
        await tester.pumpAndSettle();

        // Проверяем, что был push на routeHistoryDetail.
        expect(observer.pushedRoutes,
            contains(AppConstants.routeHistoryDetail));
      },
    );

    // ACT-04: overflow «Меню» → bottom sheet → «Очистить историю» → glass confirm → repo.clear().
    testWidgets(
      'clear_all: overflow → bottom sheet → showGlassConfirmDialog → confirm → repo.clear()',
      (tester) async {
        final entry = _makeEntry();
        final stub = _StubRepo(entries: [entry]);

        await tester.pumpWidget(_buildApp(stub: stub, entries: [entry]));
        await tester.pumpAndSettle();

        // Открываем overflow-меню (GlassIconBtn с Semantics-лейблом «Меню»).
        final overflowBtn = find.bySemanticsLabel('Меню');
        expect(overflowBtn, findsOneWidget);
        await tester.tap(overflowBtn);
        await tester.pumpAndSettle();

        // Нажимаем «Очистить историю» в стеклянном bottom sheet.
        await tester.tap(find.text('Очистить историю'));
        await tester.pumpAndSettle();

        // Появляется стеклянный confirm-диалог (GlassCard, не AlertDialog).
        expect(find.text('Очистить историю?'), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);

        // Подтверждаем — кнопка «Очистить всё».
        final confirmBtn = find.text('Очистить всё');
        expect(confirmBtn, findsOneWidget);
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        // repo.clear() должен быть вызван.
        expect(stub.clearCalled, isTrue);
      },
    );

    // Баг #1: при активных фильтрах/поиске и пустой выдаче — _EmptyNoResults, не _EmptyHistory.
    testWidgets(
      'empty_state_filters: пустая выдача с активным поиском → _EmptyNoResults (не _EmptyHistory)',
      (tester) async {
        final stub = _StubRepo(entries: const []);

        // searchTerm непустой, но searchResultsProvider отдаёт пустой список.
        await tester.pumpWidget(_buildApp(
          stub: stub,
          entries: const [],
          searchTerm: 'нет такого текста',
        ));
        await tester.pumpAndSettle();

        // Показывается экран «Ничего не найдено», а не «Расшифровок пока нет».
        expect(find.text('Ничего не найдено'), findsOneWidget);
        expect(find.text('Расшифровок пока нет'), findsNothing);
      },
    );
  });
}

// NavigatorObserver для перехвата pushNamed.
class _TestNavigatorObserver extends NavigatorObserver {
  final List<String> pushedRoutes = [];

  @override
  void didPush(Route route, Route? previousRoute) {
    final name = route.settings.name;
    if (name != null) pushedRoutes.add(name);
  }
}
