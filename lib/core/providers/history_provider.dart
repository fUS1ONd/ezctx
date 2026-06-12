import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/history/drift_history_repository.dart';
import '../../features/history/history_entry.dart';
import '../../features/history/history_repository.dart';
import 'database_provider.dart';

/// Провайдер репозитория истории на базе drift/SQLite.
/// Создаёт DriftHistoryRepository, подключённый к singleton AppDatabase (HIST-01, HIST-02).
final historyRepositoryProvider = Provider<HistoryRepository>(
  (ref) => DriftHistoryRepository(ref.watch(appDatabaseProvider)),
);

/// Стрим текущего списка записей. UI слушает его через `ref.watch`.
final historyProvider = StreamProvider<List<HistoryEntry>>((ref) {
  return ref.watch(historyRepositoryProvider).watchAll();
});
