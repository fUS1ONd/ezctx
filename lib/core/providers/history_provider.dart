import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/history/drift_history_repository.dart';
import '../../features/history/filter_notifier.dart';
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

/// Реактивный поток результатов поиска с фильтрами (SRCH-01..03, FILT-01..06, BRWS-02).
/// Наблюдает за filterNotifierProvider — при изменении FilterSpec drift
/// пересоздаёт customSelect автоматически (Open Question 2 из RESEARCH.md).
final searchResultsProvider = StreamProvider<List<HistoryEntry>>((ref) {
  final spec = ref.watch(filterNotifierProvider);
  return ref.watch(historyRepositoryProvider).watchSearch(spec);
});
