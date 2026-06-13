import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/history/drift_history_repository.dart';
import '../../features/history/filter_notifier.dart';
import '../../features/history/filter_spec.dart';
import '../../features/history/history_entry.dart';
import '../../features/history/history_repository.dart';
import 'database_provider.dart';

/// Провайдер репозитория истории на базе drift/SQLite.
/// Создаёт DriftHistoryRepository, подключённый к singleton AppDatabase (HIST-01, HIST-02).
final historyRepositoryProvider = Provider<HistoryRepository>(
  (ref) => DriftHistoryRepository(ref.watch(appDatabaseProvider)),
);

/// Стрим текущего списка записей без фильтрации. UI слушает его через `ref.watch`.
final historyProvider = StreamProvider<List<HistoryEntry>>((ref) {
  return ref.watch(historyRepositoryProvider).watchAll();
});

/// Реактивный стрим одной страницы результатов (фикс #1, BRWS-02).
/// `pageSpec` — копия текущего FilterSpec с offset = pageIndex * pageSize
/// («спека одной страницы»). autoDispose: при смене фильтра/поиска offset
/// сбрасывается в 0 — старые page-инстансы теряют наблюдателей и выгружаются.
final historyPageProvider = StreamProvider.autoDispose
    .family<List<HistoryEntry>, FilterSpec>((ref, pageSpec) {
  return ref.watch(historyRepositoryProvider).watchSearch(pageSpec);
});

/// Реактивный поток результатов поиска с фильтрами (SRCH-01..03, FILT-01..06, BRWS-02).
/// Склеивает все загруженные страницы (0..pageCount-1) из historyPageProvider
/// в один список (фикс #1 — loadMore() дополняет список, а не заменяет).
final searchResultsProvider = Provider<AsyncValue<List<HistoryEntry>>>((ref) {
  final spec = ref.watch(filterNotifierProvider);
  final pageCount = spec.offset ~/ spec.pageSize + 1;

  final firstPage = ref.watch(historyPageProvider(spec.copyWith(offset: 0)));
  if (firstPage.isLoading && !firstPage.hasValue) {
    return const AsyncValue.loading();
  }
  if (firstPage.hasError) {
    return AsyncValue.error(firstPage.error!, firstPage.stackTrace!);
  }

  final entries = [...firstPage.requireValue];
  for (var i = 1; i < pageCount; i++) {
    final page = ref.watch(
      historyPageProvider(spec.copyWith(offset: i * spec.pageSize)),
    );
    entries.addAll(page.valueOrNull ?? []);
  }
  return AsyncValue.data(entries);
});
