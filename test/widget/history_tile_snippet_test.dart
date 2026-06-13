// GREEN-реализация widget-теста сниппета (план 02-03, Task 3).
// BRWS-01: карточка показывает сниппет совпадения при активном поиске.
// CR-06: маркеры \x02/\x03 (STX/ETX) парсятся в TextSpan с выделением (жирный + accent цвет).
// Старые маркеры «» заменены — они ложно подсвечивали натуральные цитаты в тексте.
import 'package:ezctx/core/constants/design_tokens.dart';
import 'package:ezctx/core/providers/history_provider.dart';
import 'package:ezctx/features/history/filter_notifier.dart';
import 'package:ezctx/features/history/filter_spec.dart';
import 'package:ezctx/features/history/history_entry.dart';
import 'package:ezctx/features/history/history_repository.dart';
import 'package:ezctx/features/transcription/transcription_options.dart';
import 'package:ezctx/ui/screens/history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Заглушка репозитория — не обращается к реальной БД.
class _StubHistoryRepository implements HistoryRepository {
  final List<HistoryEntry> entries;
  _StubHistoryRepository({this.entries = const []});

  @override
  Stream<List<HistoryEntry>> watchAll() => Stream.value(entries);

  @override
  Future<List<HistoryEntry>> list() async => entries;

  @override
  Future<void> add(HistoryEntry entry) async {}

  @override
  Future<void> remove(String id) async {}

  @override
  Future<void> clear() async {}

  @override
  Stream<List<HistoryEntry>> watchSearch(_) => Stream.value(entries);

  @override
  Future<List<String>> distinctLanguages() async => [];

  @override
  Future<List<String>> distinctProviders() async => [];

  // Добавлен в плане 03-01 — update() обновляет title и isFavorite (ACT-01, ACT-02).
  @override
  Future<void> update(HistoryEntry entry) async {}
}

// Вспомогательная фабрика записи для тестов.
HistoryEntry _makeEntry({String? snippet}) => HistoryEntry(
      id: '1',
      fileName: 'test.ogg',
      sizeBytes: 1024,
      durationSec: 60.0,
      language: 'ru',
      createdAt: DateTime(2026, 1, 1, 12, 0),
      plainPath: '/tmp/test.txt',
      timestampedPath: '/tmp/test_ts.txt',
      title: 'Тестовая запись',
      provider: TranscriptionProviderId.groq,
      isFavorite: false,
      plainText: 'Тестовый текст расшифровки',
      snippet: snippet,
    );

// Строит HistoryScreen с overridden providerами.
// searchResultsProvider отдаёт одну запись, filterNotifierProvider — spec с активным поиском.
Widget _buildApp({required List<HistoryEntry> entries, String searchTerm = 'совпадение'}) {
  return ProviderScope(
    overrides: [
      // Переопределяем репозиторий, чтобы не лезть в реальную БД.
      historyRepositoryProvider.overrideWithValue(_StubHistoryRepository(entries: entries)),
      // Переопределяем searchResultsProvider — возвращает переданные записи напрямую.
      searchResultsProvider.overrideWith(
        (ref) => AsyncValue.data(entries),
      ),
      // Фильтр с активным поиском — показывает сниппет.
      filterNotifierProvider.overrideWith(
        () => _FixedFilterNotifier(FilterSpec(searchTerm: searchTerm)),
      ),
    ],
    child: MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      home: const HistoryScreen(),
    ),
  );
}

// Notifier с фиксированным состоянием FilterSpec — для тестов.
class _FixedFilterNotifier extends FilterNotifier {
  final FilterSpec _fixedSpec;
  _FixedFilterNotifier(this._fixedSpec);

  @override
  FilterSpec build() => _fixedSpec;
}

void main() {
    // Вспомогательная функция: рекурсивно собирает все TextSpan с текстом из InlineSpan.
  // Обходит и сам корень, и всех потомков.
  List<TextSpan> collectTextSpans(InlineSpan root) {
    final result = <TextSpan>[];

    // Обходчик с рекурсией.
    void visit(InlineSpan span) {
      if (span is TextSpan) {
        if (span.text != null && span.text!.isNotEmpty) {
          result.add(span);
        }
        if (span.children != null) {
          for (final child in span.children!) {
            visit(child);
          }
        }
      }
    }

    visit(root);
    return result;
  }

  group('buildSnippet — юнит-тесты парсинга маркеров FTS5', () {
    // Используем light-палитру напрямую (без контекста).
    const palette = AppPalette.light;
    // CR-06: маркеры STX (\x02) и ETX (\x03) вместо «».
    const open = '\x02';
    const close = '\x03';

    test('BRWS-01: текст без маркеров → 1 span с w400 и ink2', () {
      final widget = buildSnippet('просто текст', palette);
      expect(widget, isA<RichText>());
      final richText = widget as RichText;
      final spans = collectTextSpans(richText.text);
      expect(spans, hasLength(1));
      expect(spans[0].text, 'просто текст');
      expect(spans[0].style?.fontWeight, FontWeight.w400);
      expect(spans[0].style?.color, palette.ink2);
    });

    test('BRWS-01: \\x02совпадение\\x03 → 1 выделенный span с w700 и accent', () {
      final widget = buildSnippet('${open}совпадение$close', palette);
      final richText = widget as RichText;
      final spans = collectTextSpans(richText.text);
      expect(spans, hasLength(1));
      expect(spans[0].text, 'совпадение');
      expect(spans[0].style?.fontWeight, FontWeight.w700);
      expect(spans[0].style?.color, palette.accent);
    });

    test('BRWS-01: начало \\x02совпадение\\x03 конец → 3 spans, выделен средний', () {
      final widget = buildSnippet('начало ${open}совпадение$close конец', palette);
      final richText = widget as RichText;
      final spans = collectTextSpans(richText.text);
      expect(spans.length, greaterThanOrEqualTo(2));

      final highlightSpans = spans
          .where((s) => s.style?.fontWeight == FontWeight.w700)
          .toList();
      expect(highlightSpans, isNotEmpty,
          reason: 'Должен быть хотя бы один выделенный span');
      expect(
        highlightSpans.any((s) => s.text?.contains('совпадение') == true),
        isTrue,
        reason: 'Выделен должен быть текст совпадение',
      );
      for (final hs in highlightSpans) {
        expect(hs.style?.color, palette.accent,
            reason: 'Выделенный span должен иметь цвет palette.accent');
      }

      final normalSpans = spans
          .where((s) => s.style?.fontWeight == FontWeight.w400)
          .toList();
      expect(normalSpans, isNotEmpty,
          reason: 'Должны быть нормальные (невыделенные) spans');
      for (final ns in normalSpans) {
        expect(ns.style?.color, palette.ink2,
            reason: 'Нормальный span должен иметь цвет palette.ink2');
      }
    });

    test('BRWS-01: маркеры \\x02/\\x03 не присутствуют в тексте spans', () {
      final widget = buildSnippet('до ${open}выделено$close после', palette);
      final richText = widget as RichText;
      final spans = collectTextSpans(richText.text);
      for (final span in spans) {
        expect(span.text, isNot(contains(open)),
            reason: 'Маркер \\x02 не должен попасть в текст span');
        expect(span.text, isNot(contains(close)),
            reason: 'Маркер \\x03 не должен попасть в текст span');
      }
    });

    test('BRWS-01: натуральные «» в тексте НЕ подсвечиваются (CR-06)', () {
      // Текст с русскими кавычками без FTS-маркеров.
      final widget = buildSnippet('сказал «привет» другу', palette);
      final richText = widget as RichText;
      final spans = collectTextSpans(richText.text);
      // Весь текст — нормальный (нет highlight spans).
      expect(
        spans.every((s) => s.style?.fontWeight != FontWeight.w700),
        isTrue,
        reason: 'Натуральные «» не должны создавать выделенные spans',
      );
    });

    test('BRWS-01: пустой snippet → RichText с пустым списком spans', () {
      final widget = buildSnippet('', palette);
      expect(widget, isA<RichText>());
      final richText = widget as RichText;
      final spans = collectTextSpans(richText.text);
      expect(spans.where((s) => s.text?.isNotEmpty == true), isEmpty);
    });
  });

  group('HistoryScreen widget — интеграция с провайдерами', () {
    testWidgets(
      'BRWS-01: _HistoryTile рендерит snippet с выделенными \\x02/\\x03 фрагментами',
      (tester) async {
        // Запись со сниппетом: \x02совпадение\x03 выделено (CR-06 маркеры).
        final entry = _makeEntry(snippet: 'начало \x02совпадение\x03 конец');
        await tester.pumpWidget(_buildApp(entries: [entry]));
        await tester.pumpAndSettle();

        // RichText присутствует в дереве (сниппет отрендерен).
        expect(find.byType(RichText), findsWidgets,
            reason: 'RichText должен быть на экране при наличии сниппета');

        // Находим RichText с нашим сниппетом.
        bool foundHighlight = false;
        tester.widgetList<RichText>(find.byType(RichText)).forEach((rt) {
          rt.text.visitChildren((span) {
            if (span is TextSpan &&
                span.text?.contains('совпадение') == true &&
                span.style?.fontWeight == FontWeight.w700) {
              foundHighlight = true;
            }
            return true;
          });
        });
        expect(foundHighlight, isTrue,
            reason:
                'Должен быть TextSpan с «совпадение» и FontWeight.w700');
      },
    );

    testWidgets(
      'BRWS-01: _HistoryTile без snippet НЕ рендерит сниппет-RichText',
      (tester) async {
        // Запись без сниппета (snippet == null).
        final entry = _makeEntry(snippet: null);
        await tester.pumpWidget(_buildApp(entries: [entry], searchTerm: ''));
        await tester.pumpAndSettle();

        // Сниппет-RichText имеет maxLines: 2 — ищем только такие виджеты.
        // Обычные тексты в тайлах (заголовок, мета) не используют maxLines:2.
        final snippetRichTexts = tester
            .widgetList<RichText>(find.byType(RichText))
            .where((rt) => rt.maxLines == 2)
            .toList();

        // При snippet==null не должно быть RichText с maxLines:2.
        expect(snippetRichTexts, isEmpty,
            reason:
                'При snippet==null сниппет-RichText (maxLines:2) не должен рендериться');
      },
    );
  });
}
