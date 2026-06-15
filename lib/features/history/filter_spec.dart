import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange;

// Sentinel для copyWith: позволяет явно передать null в nullable-поля.
const Object _absent = Object();

// Пресеты длительности расшифровки (D-04 — взаимоисключающие radio-чипы).
// short=<10мин, medium=10–60мин, long=>1ч.
enum DurationPreset { short, medium, long }

/// Единая модель состояния поиска и фильтров (D-06).
/// Immutable value object — изменения происходят только через copyWith/resetAll
/// в FilterNotifier (план 02).
///
/// Поля:
/// - [searchTerm] — строка полнотекстового поиска (SRCH-01); НЕ является фильтром
///   (не учитывается в [hasActiveFilters]).
/// - [durationPreset] — взаимоисключающий radio-пресет длительности (D-04, FILT-04).
/// - [todayOnly] — независимый тоггл «Сегодня» (D-05, FILT-01).
/// - [favoriteOnly] — независимый тоггл «★ Избранное» (D-05, FILT-05).
/// - [dateRange] — произвольный диапазон дат из bottom sheet (FILT-01).
/// - [languages] — множество выбранных языков (FILT-02).
/// - [providers] — множество выбранных провайдеров (FILT-03).
/// - [offset]/[pageSize] — параметры пагинации (BRWS-02).
@immutable
class FilterSpec {
  const FilterSpec({
    this.searchTerm = '',
    this.durationPreset,
    this.todayOnly = false,
    this.favoriteOnly = false,
    this.dateRange,
    this.languages = const {},
    this.providers = const {},
    this.offset = 0,
    this.pageSize = 50,
  })  : assert(offset >= 0, 'offset не может быть отрицательным'),
        assert(pageSize > 0, 'pageSize должен быть > 0');

  final String searchTerm;

  // Пресет длительности — null означает «без ограничения» (D-04).
  final DurationPreset? durationPreset;

  // Независимые тогглы (D-05).
  final bool todayOnly;
  final bool favoriteOnly;

  // Произвольный диапазон дат из bottom sheet (FILT-01).
  final DateTimeRange? dateRange;

  // Множества выбранных значений (FILT-02, FILT-03).
  final Set<String> languages;
  final Set<String> providers;

  // Параметры пагинации (BRWS-02).
  final int offset;
  final int pageSize;

  // Возвращает true если активен любой из фильтров (не учитывает searchTerm).
  // Используется для определения состояния «ничего не найдено» vs «история пуста» (D-09).
  bool get hasActiveFilters =>
      durationPreset != null ||
      todayOnly ||
      favoriteOnly ||
      dateRange != null ||
      languages.isNotEmpty ||
      providers.isNotEmpty;

  // Счётчик активных фильтров bottom sheet (dateRange + languages + providers).
  // Используется для индикатора числа активных фильтров на кнопке bottom sheet.
  int get activeSheetFilterCount =>
      (dateRange != null ? 1 : 0) + languages.length + providers.length;

  // Сбрасывает все поля к дефолтам (полный reset фильтров и поиска).
  FilterSpec resetAll() => const FilterSpec();

  /// copyWith с sentinel-pattern для nullable-полей (durationPreset, dateRange).
  /// По умолчанию поле сохраняется. Передача явного null обнуляет поле:
  ///   `spec.copyWith(durationPreset: null)` — сброс пресета.
  FilterSpec copyWith({
    String? searchTerm,
    Object? durationPreset = _absent,
    bool? todayOnly,
    bool? favoriteOnly,
    Object? dateRange = _absent,
    Set<String>? languages,
    Set<String>? providers,
    int? offset,
    int? pageSize,
  }) =>
      FilterSpec(
        searchTerm: searchTerm ?? this.searchTerm,
        durationPreset: durationPreset == _absent
            ? this.durationPreset
            : durationPreset as DurationPreset?,
        todayOnly: todayOnly ?? this.todayOnly,
        favoriteOnly: favoriteOnly ?? this.favoriteOnly,
        dateRange: dateRange == _absent
            ? this.dateRange
            : dateRange as DateTimeRange?,
        languages: languages ?? this.languages,
        providers: providers ?? this.providers,
        offset: offset ?? this.offset,
        pageSize: pageSize ?? this.pageSize,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FilterSpec) return false;
    return searchTerm == other.searchTerm &&
        durationPreset == other.durationPreset &&
        todayOnly == other.todayOnly &&
        favoriteOnly == other.favoriteOnly &&
        dateRange == other.dateRange &&
        setEquals(languages, other.languages) &&
        setEquals(providers, other.providers) &&
        offset == other.offset &&
        pageSize == other.pageSize;
  }

  @override
  int get hashCode => Object.hash(
        searchTerm,
        durationPreset,
        todayOnly,
        favoriteOnly,
        dateRange,
        Object.hashAllUnordered(languages),
        Object.hashAllUnordered(providers),
        offset,
        pageSize,
      );
}
