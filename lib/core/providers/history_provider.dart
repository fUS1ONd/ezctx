import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/history/history_entry.dart';
import '../../features/history/history_repository.dart';

/// Источник правды для UI истории.
/// По умолчанию — in-memory заглушка с пустым списком. Когда будет готова
/// настоящая реализация (SharedPreferences/SQLite), переопредели здесь и в
/// ProviderScope.
final historyRepositoryProvider = Provider<HistoryRepository>(
  (ref) => InMemoryHistoryRepository(),
);

/// Стрим текущего списка записей. UI слушает его через `ref.watch`.
final historyProvider = StreamProvider<List<HistoryEntry>>((ref) {
  return ref.watch(historyRepositoryProvider).watchAll();
});
