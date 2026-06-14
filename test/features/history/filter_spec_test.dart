import 'package:ezctx/features/history/filter_spec.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FilterSpec defaults', () {
    test('пустой FilterSpec имеет ожидаемые значения по умолчанию', () {
      const spec = FilterSpec();
      expect(spec.searchTerm, '');
      expect(spec.durationPreset, isNull);
      expect(spec.todayOnly, false);
      expect(spec.favoriteOnly, false);
      expect(spec.dateRange, isNull);
      expect(spec.languages, isEmpty);
      expect(spec.providers, isEmpty);
      expect(spec.offset, 0);
      expect(spec.pageSize, 50);
    });

    // SRCH-01: hasActiveFilters false при пустом FilterSpec.
    test('hasActiveFilters == false при пустом FilterSpec', () {
      const spec = FilterSpec();
      expect(spec.hasActiveFilters, false);
    });

    // Поиск не является фильтром (D-06).
    test('hasActiveFilters НЕ зависит от searchTerm', () {
      const spec = FilterSpec(searchTerm: 'лекция');
      expect(spec.hasActiveFilters, false);
    });
  });

  group('FilterSpec hasActiveFilters', () {
    test('true при favoriteOnly=true', () {
      const spec = FilterSpec(favoriteOnly: true);
      expect(spec.hasActiveFilters, true);
    });

    test('true при todayOnly=true', () {
      const spec = FilterSpec(todayOnly: true);
      expect(spec.hasActiveFilters, true);
    });

    test('true при durationPreset != null', () {
      const spec = FilterSpec(durationPreset: DurationPreset.short);
      expect(spec.hasActiveFilters, true);
    });

    test('true при dateRange != null', () {
      final now = DateTime.now();
      final spec = FilterSpec(
        dateRange: DateTimeRange(start: now, end: now),
      );
      expect(spec.hasActiveFilters, true);
    });

    test('true при непустых languages', () {
      const spec = FilterSpec(languages: {'russian'});
      expect(spec.hasActiveFilters, true);
    });

    test('true при непустых providers', () {
      const spec = FilterSpec(providers: {'groq'});
      expect(spec.hasActiveFilters, true);
    });

    test('false при searchTerm + все фильтры по умолчанию', () {
      const spec = FilterSpec(searchTerm: 'что-то');
      expect(spec.hasActiveFilters, false);
    });
  });

  group('FilterSpec activeSheetFilterCount', () {
    test('0 при пустом FilterSpec', () {
      const spec = FilterSpec();
      expect(spec.activeSheetFilterCount, 0);
    });

    test('1 при dateRange != null', () {
      final now = DateTime.now();
      final spec = FilterSpec(
        dateRange: DateTimeRange(start: now, end: now),
      );
      expect(spec.activeSheetFilterCount, 1);
    });

    test('считает элементы в languages', () {
      const spec = FilterSpec(languages: {'russian', 'english'});
      expect(spec.activeSheetFilterCount, 2);
    });

    test('считает элементы в providers', () {
      const spec = FilterSpec(providers: {'groq'});
      expect(spec.activeSheetFilterCount, 1);
    });

    test('суммирует dateRange + languages + providers', () {
      final now = DateTime.now();
      final spec = FilterSpec(
        dateRange: DateTimeRange(start: now, end: now),
        languages: const {'russian', 'english'},
        providers: const {'groq'},
      );
      // 1 + 2 + 1 = 4
      expect(spec.activeSheetFilterCount, 4);
    });

    test('НЕ считает durationPreset/todayOnly/favoriteOnly', () {
      const spec = FilterSpec(
        durationPreset: DurationPreset.medium,
        todayOnly: true,
        favoriteOnly: true,
      );
      expect(spec.activeSheetFilterCount, 0);
    });
  });

  group('FilterSpec copyWith', () {
    test('copyWith(searchTerm) меняет только searchTerm', () {
      const original = FilterSpec(favoriteOnly: true, todayOnly: true);
      final copy = original.copyWith(searchTerm: 'x');
      expect(copy.searchTerm, 'x');
      // остальные поля сохранились
      expect(copy.favoriteOnly, true);
      expect(copy.todayOnly, true);
      expect(copy.durationPreset, isNull);
    });

    test('copyWith(favoriteOnly) не меняет searchTerm', () {
      const original = FilterSpec(searchTerm: 'тест');
      final copy = original.copyWith(favoriteOnly: true);
      expect(copy.favoriteOnly, true);
      expect(copy.searchTerm, 'тест');
    });

    test('copyWith(durationPreset) меняет только durationPreset', () {
      const original = FilterSpec(todayOnly: true);
      final copy = original.copyWith(durationPreset: DurationPreset.long);
      expect(copy.durationPreset, DurationPreset.long);
      expect(copy.todayOnly, true);
    });

    test('copyWith(offset) сохраняет pageSize', () {
      const original = FilterSpec(pageSize: 20);
      final copy = original.copyWith(offset: 50);
      expect(copy.offset, 50);
      expect(copy.pageSize, 20);
    });
  });

  group('FilterSpec resetAll', () {
    test('возвращает const FilterSpec() со всеми дефолтами', () {
      const defaultSpec = FilterSpec();
      final reset = FilterSpec(
        searchTerm: 'что-то',
        favoriteOnly: true,
        todayOnly: true,
      ).resetAll();
      expect(reset, equals(defaultSpec));
    });

    test('resetAll сбрасывает offset и pageSize к дефолтам', () {
      final reset = const FilterSpec(offset: 100, pageSize: 20).resetAll();
      expect(reset.offset, 0);
      expect(reset.pageSize, 50);
    });
  });

  group('FilterSpec equality', () {
    test('два FilterSpec с равными полями равны', () {
      const a = FilterSpec(searchTerm: 'тест', favoriteOnly: true);
      const b = FilterSpec(searchTerm: 'тест', favoriteOnly: true);
      expect(a, equals(b));
    });

    test('hashCode совпадает для равных объектов', () {
      const a = FilterSpec(searchTerm: 'тест', favoriteOnly: true);
      const b = FilterSpec(searchTerm: 'тест', favoriteOnly: true);
      expect(a.hashCode, b.hashCode);
    });

    test('разные FilterSpec не равны', () {
      const a = FilterSpec(favoriteOnly: true);
      const b = FilterSpec(favoriteOnly: false);
      expect(a, isNot(equals(b)));
    });

    test('FilterSpec с разными languages не равны', () {
      const a = FilterSpec(languages: {'russian'});
      const b = FilterSpec(languages: {'english'});
      expect(a, isNot(equals(b)));
    });
  });

  group('DurationPreset enum', () {
    test('содержит short, medium, long', () {
      expect(DurationPreset.values, containsAll([
        DurationPreset.short,
        DurationPreset.medium,
        DurationPreset.long,
      ]));
    });
  });
}
