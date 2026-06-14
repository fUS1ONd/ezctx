// Widget-тест нижнего отступа списка истории (фикс бага #2, BUGS.md).
//
// Баг: карточки уходят под плавающий нижний навбар. Внешний Scaffold с
// extendBody:true инжектит высоту бара в MediaQuery.padding.bottom, но
// внутренний SafeArea его поглощал → список упирался в бар и не уходил под
// стекло. Фикс: SafeArea(bottom:false) пропускает inset до списка, а ListView
// сам резервирует padding.bottom = MediaQuery.padding.bottom + зазор.
import 'package:ezctx/core/providers/history_provider.dart';
import 'package:ezctx/features/history/filter_spec.dart';
import 'package:ezctx/features/history/history_entry.dart';
import 'package:ezctx/features/history/history_repository.dart';
import 'package:ezctx/features/transcription/transcription_options.dart';
import 'package:ezctx/ui/screens/history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubRepo implements HistoryRepository {
  _StubRepo(this.entries);

  final List<HistoryEntry> entries;

  @override
  Stream<List<HistoryEntry>> watchSearch(FilterSpec spec) =>
      Stream.value(entries);

  @override
  Stream<List<HistoryEntry>> watchAll() => Stream.value(entries);

  @override
  Future<List<HistoryEntry>> list() async => entries;

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
      plainText: 'Текст записи $id для widget-теста отступа.',
    );

void main() {
  testWidgets(
    'список резервирует MediaQuery safe-area + зазор снизу под бар (#2)',
    (tester) async {
      final repo = _StubRepo(List.generate(5, (i) => _makeEntry('$i')));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [historyRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
              useMaterial3: true,
            ),
            // Имитируем нижний inset (высота бара + safe-area), который
            // внешний extendBody:true инжектит в padding.bottom.
            home: const MediaQuery(
              data: MediaQueryData(padding: EdgeInsets.only(bottom: 50)),
              child: HistoryScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final listView = tester.widget<ListView>(find.byType(ListView));
      final padding = listView.padding as EdgeInsets;

      // 50 (инжектированный inset бара+safe-area) + 16 (зазор над баром).
      expect(padding.bottom, 50 + 16);
    },
  );
}
