import 'dart:async';

import 'filter_spec.dart';
import 'history_entry.dart';

/// Контракт репозитория истории расшифровок.
/// Реализуется DriftHistoryRepository (SQLite через drift).
abstract class HistoryRepository {
  Stream<List<HistoryEntry>> watchAll();
  Future<List<HistoryEntry>> list();
  Future<void> add(HistoryEntry entry);
  Future<void> remove(String id);
  Future<void> clear();

  /// Параметризованный поиск с фильтрами (SRCH-01, FILT-01..06).
  /// Возвращает поток: drift переиздаёт при изменении transcripts.
  /// HistoryEntry в результатах может содержать snippet при активном searchTerm.
  Stream<List<HistoryEntry>> watchSearch(FilterSpec spec);

  /// Список уникальных языков из истории для чипов bottom sheet (D-07, FILT-02).
  Future<List<String>> distinctLanguages();

  /// Список уникальных провайдеров из истории для чипов bottom sheet (D-07, FILT-03).
  Future<List<String>> distinctProviders();

  /// Обновляет title и isFavorite существующей записи (ACT-01, ACT-02).
  /// Идентификация по entry.id. Остальные поля (plainText, fileName и т.д.) не изменяются.
  Future<void> update(HistoryEntry entry);
}
