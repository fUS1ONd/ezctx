import 'dart:async';

import 'history_entry.dart';

/// Контракт репозитория истории. Реальная реализация (например, на
/// SharedPreferences или sqlite) появится в следующей фазе — на UI-уровне это
/// не важно, экран и провайдер уже работают по этому интерфейсу.
abstract class HistoryRepository {
  Stream<List<HistoryEntry>> watchAll();
  Future<List<HistoryEntry>> list();
  Future<void> add(HistoryEntry entry);
  Future<void> remove(String id);
  Future<void> clear();
}

/// Заглушка для UI-фазы. Держит всё в памяти; при рестарте откатится к пустому
/// списку.
///
/// Подменяй на реальную реализацию через override `historyRepositoryProvider`
/// в `lib/core/providers/history_provider.dart`.
class InMemoryHistoryRepository implements HistoryRepository {
  InMemoryHistoryRepository({List<HistoryEntry>? seed})
      : _entries = List.of(seed ?? const <HistoryEntry>[]);

  final List<HistoryEntry> _entries;
  final StreamController<List<HistoryEntry>> _controller =
      StreamController.broadcast();

  void _broadcast() => _controller.add(List.unmodifiable(_entries));

  @override
  Stream<List<HistoryEntry>> watchAll() async* {
    yield List.unmodifiable(_entries);
    yield* _controller.stream;
  }

  @override
  Future<List<HistoryEntry>> list() async => List.unmodifiable(_entries);

  @override
  Future<void> add(HistoryEntry entry) async {
    _entries.insert(0, entry);
    _broadcast();
  }

  @override
  Future<void> remove(String id) async {
    _entries.removeWhere((e) => e.id == id);
    _broadcast();
  }

  @override
  Future<void> clear() async {
    _entries.clear();
    _broadcast();
  }
}
