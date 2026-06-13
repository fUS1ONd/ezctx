// Widget-тесты пагинации HistoryScreen (фикс бага #1, BRWS-02).
// Спека: docs/superpowers/specs/2026-06-13-history-pagination-collapse-design.md
//
// _OffsetPagedRepo — стаб HistoryRepository, отдающий записи по offset из
// карты pages (имитирует LIMIT/OFFSET drift) и записывающий все запрошенные
// offset'ы для проверки guard reachedEnd (Task 4).
import 'package:ezctx/core/providers/history_provider.dart';
import 'package:ezctx/features/history/filter_spec.dart';
import 'package:ezctx/features/history/history_entry.dart';
import 'package:ezctx/features/history/history_repository.dart';
import 'package:ezctx/features/transcription/transcription_options.dart';
import 'package:ezctx/ui/screens/history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _OffsetPagedRepo implements HistoryRepository {
  _OffsetPagedRepo(this.pages);

  final Map<int, List<HistoryEntry>> pages;
  final List<int> requestedOffsets = [];

  @override
  Stream<List<HistoryEntry>> watchSearch(FilterSpec spec) {
    requestedOffsets.add(spec.offset);
    return Stream.value(pages[spec.offset] ?? const []);
  }

  @override
  Stream<List<HistoryEntry>> watchAll() => Stream.value(pages[0] ?? const []);

  @override
  Future<List<HistoryEntry>> list() async => pages[0] ?? const [];

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

HistoryEntry _makeEntry(String id) => HistoryEntry(
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
      plainText: 'Текст записи $id для widget-теста пагинации.',
    );

Widget _buildApp(_OffsetPagedRepo repo) {
  return ProviderScope(
    overrides: [
      historyRepositoryProvider.overrideWithValue(repo),
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
  group('HistoryScreen pagination — фикс #1', () {
    // BUGS.md #1: список короче pageSize (30 < 50) — скролл к концу не
    // должен схлопывать список в _EmptyHistory.
    testWidgets(
      'короткий список не схлопывается в _EmptyHistory после скролла',
      (tester) async {
        final entries = List.generate(30, (i) => _makeEntry('$i'));
        final repo = _OffsetPagedRepo({0: entries});

        await tester.pumpWidget(_buildApp(repo));
        await tester.pumpAndSettle();

        expect(find.text('Запись 0'), findsOneWidget);

        // Несколько drag к концу списка — каждый вызывает _onScroll.
        // Один большой drag с pumpAndSettle не гарантированно пересекает
        // порог (maxScrollExtent - 300) из-за overscroll-физики, поэтому
        // повторяем drag несколько раз с промежуточными pump (без settle —
        // иначе тест не успевает зафиксировать промежуточное состояние
        // сразу после срабатывания _onScroll → loadMore()).
        for (var i = 0; i < 5; i++) {
          if (find.byType(ListView).evaluate().isEmpty) break;
          await tester.drag(find.byType(ListView), const Offset(0, -2000));
          await tester.pump();
        }
        await tester.pumpAndSettle();

        expect(find.text('Расшифровок пока нет'), findsNothing);
        expect(find.byType(ListView), findsOneWidget);
      },
    );

    // Guard reachedEnd: список короче pageSize — скролл к концу не должен
    // вызывать loadMore() вовсе (данных за пределами страницы 0 нет).
    // Используем тот же loop-паттерн drag+pump, что и первый тест: единственный
    // большой drag с pumpAndSettle не гарантированно пересекает порог
    // (maxScrollExtent - 300) из-за overscroll-физики виджет-тестового окружения.
    testWidgets(
      'guard reachedEnd: короткий список — скролл к концу не вызывает loadMore',
      (tester) async {
        final entries = List.generate(30, (i) => _makeEntry('$i'));
        final repo = _OffsetPagedRepo({0: entries});

        await tester.pumpWidget(_buildApp(repo));
        await tester.pumpAndSettle();

        for (var i = 0; i < 5; i++) {
          if (find.byType(ListView).evaluate().isEmpty) break;
          await tester.drag(find.byType(ListView), const Offset(0, -2000));
          await tester.pump();
        }
        await tester.pumpAndSettle();

        expect(repo.requestedOffsets, [0]);
      },
    );
  });
}
