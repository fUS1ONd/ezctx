import 'dart:async';

import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'filter_spec.dart';

/// Notifier состояния поиска и фильтров (Riverpod 2.x Notifier, не StateNotifier — deprecated).
/// Управляет единой моделью FilterSpec: debounce поиска, синхронизация чипов/sheet (D-06),
/// пагинация (BRWS-02), сброс offset при смене фильтра (Pitfall 5).
class FilterNotifier extends Notifier<FilterSpec> {
  /// Таймер debounce для поиска — отменяется при каждом новом вызове setSearch (SRCH-03).
  Timer? _debounce;

  @override
  FilterSpec build() => const FilterSpec();

  /// Отменяем таймер при destroy — предотвращаем утечку памяти (T-02-07, A4 из RESEARCH.md).
  // ignore: must_call_super — Notifier в Riverpod 2.x не объявляет dispose как super-метод.
  void dispose() {
    _debounce?.cancel();
  }

  /// Обновляет строку поиска с debounce 250 мс (SRCH-03).
  /// Offset сбрасывается в 0 при каждом применении (Pitfall 5).
  void setSearch(String term) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      state = state.copyWith(searchTerm: term, offset: 0);
    });
  }

  /// Выставляет пресет длительности немедленно (FILT-04, D-04 — radio-выбор).
  /// null = сброс пресета без ограничения по длительности.
  /// Offset сбрасывается в 0 (Pitfall 5).
  void setDurationPreset(DurationPreset? preset) {
    // copyWith не поддерживает null для nullable-полей — присваиваем state напрямую.
    state = FilterSpec(
      searchTerm: state.searchTerm,
      durationPreset: preset,
      todayOnly: state.todayOnly,
      favoriteOnly: state.favoriteOnly,
      dateRange: state.dateRange,
      languages: state.languages,
      providers: state.providers,
      offset: 0,
      pageSize: state.pageSize,
    );
  }

  /// Тоггл «Сегодня» (FILT-01, D-05).
  /// При true синхронизирует dateRange с сегодняшним днём (D-06).
  /// При false очищает dateRange.
  /// Offset сбрасывается в 0 (Pitfall 5).
  void setTodayOnly(bool value) {
    final DateTimeRange? newDateRange;
    if (value) {
      final now = DateTime.now();
      newDateRange = DateTimeRange(
        start: DateTime(now.year, now.month, now.day),
        end: DateTime(now.year, now.month, now.day, 23, 59, 59),
      );
    } else {
      newDateRange = null;
    }
    // Явное присваивание для обнуления dateRange при value=false.
    state = FilterSpec(
      searchTerm: state.searchTerm,
      durationPreset: state.durationPreset,
      todayOnly: value,
      favoriteOnly: state.favoriteOnly,
      dateRange: newDateRange,
      languages: state.languages,
      providers: state.providers,
      offset: 0,
      pageSize: state.pageSize,
    );
  }

  /// Тоггл «★ Избранное» (FILT-05, D-05).
  /// Offset сбрасывается в 0 (Pitfall 5).
  void setFavoriteOnly(bool value) {
    state = state.copyWith(favoriteOnly: value, offset: 0);
  }

  /// Применяет фильтры из bottom sheet (диапазон дат, языки, провайдеры).
  /// Синхронизирует todayOnly с dateRange (D-06, Pitfall 4):
  /// если dateRange совпадает с сегодняшним днём — todayOnly=true, иначе false.
  /// Offset сбрасывается в 0 (Pitfall 5).
  void applySheetFilters({
    DateTimeRange? dateRange,
    Set<String>? languages,
    Set<String>? providers,
  }) {
    final isToday = dateRange != null && _isTodayRange(dateRange);
    state = FilterSpec(
      searchTerm: state.searchTerm,
      durationPreset: state.durationPreset,
      todayOnly: isToday,
      favoriteOnly: state.favoriteOnly,
      dateRange: dateRange,
      languages: languages ?? state.languages,
      providers: providers ?? state.providers,
      offset: 0,
      pageSize: state.pageSize,
    );
  }

  /// Подгружает следующую страницу — сдвигает offset на pageSize (BRWS-02).
  /// Единственный метод, который НЕ сбрасывает offset в 0 (Pitfall 5).
  void loadMore() {
    state = state.copyWith(offset: state.offset + state.pageSize);
  }

  /// Сбрасывает всё состояние к дефолтному FilterSpec() (resetAll).
  void resetAll() {
    _debounce?.cancel();
    state = const FilterSpec();
  }

  /// Проверяет, совпадает ли dateRange с сегодняшним днём (D-06, Pitfall 4).
  /// Сравнение start == начало дня AND end == конец дня (23:59:59).
  bool _isTodayRange(DateTimeRange range) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return _isSameDay(range.start, todayStart) &&
        _isSameDay(range.end, todayEnd);
  }

  /// Проверяет совпадение двух дат до секунды (вспомогательный метод D-06).
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day &&
        a.hour == b.hour &&
        a.minute == b.minute &&
        a.second == b.second;
  }
}

/// Провайдер состояния фильтров поиска.
/// Тип: NotifierProvider (Riverpod 2.x) — не StateNotifierProvider (deprecated).
final filterNotifierProvider = NotifierProvider<FilterNotifier, FilterSpec>(
  FilterNotifier.new,
);
