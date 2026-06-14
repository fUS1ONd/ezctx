// Widget-тест overflow заглушки «Ничего не найдено» при открытой клавиатуре.
//
// Баг: при активном поиске без результатов и поднятой клавиатуре body
// сжимается на высоту клавиатуры → Expanded уменьшается → фиксированная
// заглушка _EmptyNoResults не влезает → «bottom overflowed by N pixels».
// Фикс: resizeToAvoidBottomInset:false на Scaffold (клавиатура наезжает
// поверх, body сохраняет высоту). См. также внешний ScaffoldWithNavBar.
import 'package:ezctx/core/providers/history_provider.dart';
import 'package:ezctx/features/history/filter_notifier.dart';
import 'package:ezctx/features/history/filter_spec.dart';
import 'package:ezctx/features/history/history_entry.dart';
import 'package:ezctx/features/history/history_repository.dart';
import 'package:ezctx/ui/screens/history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Стаб-репозиторий, всегда возвращающий пустой список (нет результатов поиска).
class _EmptyRepo implements HistoryRepository {
  @override
  Stream<List<HistoryEntry>> watchSearch(FilterSpec spec) => Stream.value(const []);

  @override
  Stream<List<HistoryEntry>> watchAll() => Stream.value(const []);

  @override
  Future<List<HistoryEntry>> list() async => const [];

  @override
  Future<void> add(HistoryEntry entry) async {}

  @override
  Future<void> remove(String id) async {}

  @override
  Future<void> clear() async {}

  @override
  Future<List<String>> distinctLanguages() async => const [];

  @override
  Future<List<String>> distinctProviders() async => const [];

  @override
  Future<void> update(HistoryEntry entry) async {}
}

void main() {
  testWidgets(
    'заглушка «Ничего не найдено» не даёт overflow при поднятой клавиатуре',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [historyRepositoryProvider.overrideWithValue(_EmptyRepo())],
          child: MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
              useMaterial3: true,
            ),
            // viewInsets.bottom=300 имитирует поднятую клавиатуру.
            home: const MediaQuery(
              data: MediaQueryData(viewInsets: EdgeInsets.only(bottom: 300)),
              child: HistoryScreen(),
            ),
          ),
        ),
      );

      // Активируем поиск → показывается _EmptyNoResults (D-09).
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HistoryScreen)),
      );
      container.read(filterNotifierProvider.notifier).setSearch('несуществующий запрос');
      // Ждём debounce 250 мс + рендер.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      // Заглушка отрисована, overflow отсутствует.
      expect(find.text('Ничего не найдено'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
