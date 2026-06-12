import 'dart:async';

import 'history_entry.dart';

/// Контракт репозитория истории расшифровок.
/// Реализуется DriftHistoryRepository (SQLite через drift).
abstract class HistoryRepository {
  Stream<List<HistoryEntry>> watchAll();
  Future<List<HistoryEntry>> list();
  Future<void> add(HistoryEntry entry);
  Future<void> remove(String id);
  Future<void> clear();
}
