// Тесты FilterNotifier: debounce, фильтры, синхронизация D-06, offset.
// Требования: SRCH-03 (debounce), D-06 (todayOnly↔dateRange), Pitfall 5 (offset reset).
import 'package:ezctx/features/history/filter_notifier.dart';
import 'package:ezctx/features/history/filter_spec.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    // Изолированный контейнер для каждого теста.
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  // SRCH-03: debounce 250 мс — state не меняется сразу после вызова setSearch.
  test('SRCH-03: setSearch не меняет state немедленно', () {
    container.read(filterNotifierProvider.notifier).setSearch('тест');
    // Сразу после вызова state остаётся прежним.
    expect(container.read(filterNotifierProvider).searchTerm, equals(''));
  });

  test('SRCH-03: setSearch обновляет state после 250 мс', () async {
    container.read(filterNotifierProvider.notifier).setSearch('тест');
    // Ждём 300 мс — таймер должен сработать.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(container.read(filterNotifierProvider).searchTerm, equals('тест'));
  });

  test('SRCH-03: быстрые подряд setSearch → применяется только последний',
      () async {
    final notifier = container.read(filterNotifierProvider.notifier);
    notifier.setSearch('a');
    notifier.setSearch('ab');
    notifier.setSearch('abc');

    // До истечения таймера state не изменился.
    expect(container.read(filterNotifierProvider).searchTerm, equals(''));

    // После 300 мс — применился только последний вызов.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(container.read(filterNotifierProvider).searchTerm, equals('abc'));
  });

  // setSearch сбрасывает offset при применении (Pitfall 5).
  test('setSearch сбрасывает offset в 0 при применении', () async {
    final notifier = container.read(filterNotifierProvider.notifier);
    notifier.loadMore(); // offset = pageSize по умолчанию
    final pageSize = container.read(filterNotifierProvider).pageSize;
    expect(container.read(filterNotifierProvider).offset, equals(pageSize));

    notifier.setSearch('query');
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final state = container.read(filterNotifierProvider);
    expect(state.searchTerm, equals('query'));
    expect(state.offset, equals(0));
  });

  // setDurationPreset применяется немедленно и сбрасывает offset.
  test('setDurationPreset применяется немедленно и сбрасывает offset', () {
    final notifier = container.read(filterNotifierProvider.notifier);
    notifier.loadMore(); // offset = 50
    notifier.setDurationPreset(DurationPreset.short);

    final state = container.read(filterNotifierProvider);
    expect(state.durationPreset, equals(DurationPreset.short));
    expect(state.offset, equals(0));
  });

  test('setDurationPreset(null) сбрасывает пресет', () {
    final notifier = container.read(filterNotifierProvider.notifier);
    notifier.setDurationPreset(DurationPreset.medium);
    notifier.setDurationPreset(null);

    expect(container.read(filterNotifierProvider).durationPreset, isNull);
  });

  // setFavoriteOnly сбрасывает offset.
  test('setFavoriteOnly выставляет флаг и сбрасывает offset', () {
    final notifier = container.read(filterNotifierProvider.notifier);
    notifier.loadMore();
    notifier.setFavoriteOnly(true);

    final state = container.read(filterNotifierProvider);
    expect(state.favoriteOnly, isTrue);
    expect(state.offset, equals(0));
  });

  // D-06: setTodayOnly(true) выставляет dateRange = сегодняшний день.
  test('D-06: setTodayOnly(true) выставляет dateRange на сегодня', () {
    container.read(filterNotifierProvider.notifier).setTodayOnly(true);

    final state = container.read(filterNotifierProvider);
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    expect(state.todayOnly, isTrue);
    expect(state.dateRange, isNotNull);
    expect(state.dateRange!.start, equals(todayStart));
    expect(state.dateRange!.end, equals(todayEnd));
    expect(state.offset, equals(0));
  });

  // D-06: setTodayOnly(false) очищает dateRange.
  test('D-06: setTodayOnly(false) очищает dateRange', () {
    final notifier = container.read(filterNotifierProvider.notifier);
    notifier.setTodayOnly(true);
    notifier.setTodayOnly(false);

    final state = container.read(filterNotifierProvider);
    expect(state.todayOnly, isFalse);
    expect(state.dateRange, isNull);
  });

  // D-06: applySheetFilters с dateRange == сегодня → todayOnly=true (Pitfall 4).
  test('D-06: applySheetFilters с dateRange=сегодня → todayOnly=true', () {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    container.read(filterNotifierProvider.notifier).applySheetFilters(
      dateRange: DateTimeRange(start: todayStart, end: todayEnd),
    );

    final state = container.read(filterNotifierProvider);
    expect(state.todayOnly, isTrue);
    expect(state.dateRange, isNotNull);
    expect(state.offset, equals(0));
  });

  // D-06: applySheetFilters с другим диапазоном → todayOnly=false.
  test('D-06: applySheetFilters с диапазоном не сегодня → todayOnly=false',
      () {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final rangeStart =
        DateTime(yesterday.year, yesterday.month, yesterday.day);
    final rangeEnd =
        DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);

    container.read(filterNotifierProvider.notifier).applySheetFilters(
      dateRange: DateTimeRange(start: rangeStart, end: rangeEnd),
    );

    final state = container.read(filterNotifierProvider);
    expect(state.todayOnly, isFalse);
    expect(state.dateRange, isNotNull);
    expect(state.offset, equals(0));
  });

  // loadMore сдвигает offset на pageSize (Pitfall 5 — loadMore НЕ сбрасывает offset).
  test('loadMore() увеличивает offset на pageSize', () {
    final notifier = container.read(filterNotifierProvider.notifier);
    final pageSize = container.read(filterNotifierProvider).pageSize;

    expect(container.read(filterNotifierProvider).offset, equals(0));
    notifier.loadMore();
    expect(container.read(filterNotifierProvider).offset, equals(pageSize));
    notifier.loadMore();
    expect(container.read(filterNotifierProvider).offset, equals(pageSize * 2));
  });

  // resetAll возвращает const FilterSpec().
  test('resetAll() сбрасывает всё состояние в дефолт', () {
    final notifier = container.read(filterNotifierProvider.notifier);
    notifier.setFavoriteOnly(true);
    notifier.setDurationPreset(DurationPreset.long);
    notifier.loadMore();

    notifier.resetAll();

    final state = container.read(filterNotifierProvider);
    expect(state, equals(const FilterSpec()));
    expect(state.favoriteOnly, isFalse);
    expect(state.durationPreset, isNull);
    expect(state.offset, equals(0));
  });

  // filterNotifierProvider — NotifierProvider (не StateNotifierProvider).
  test('filterNotifierProvider является NotifierProvider', () {
    expect(
      filterNotifierProvider,
      isA<NotifierProvider<FilterNotifier, FilterSpec>>(),
    );
  });
}
