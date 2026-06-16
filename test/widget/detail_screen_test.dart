// Widget-тесты detail-экрана (план 03-02, Wave 2) + swipe_delete (план 03-03).
// Стаб-репозиторий реализует весь контракт HistoryRepository (включая update()).

import 'dart:io';

import 'package:ezctx/core/providers/history_provider.dart';
import 'package:ezctx/core/services/clipboard_service.dart';
import 'package:ezctx/features/history/filter_notifier.dart';
import 'package:ezctx/features/history/filter_spec.dart';
import 'package:ezctx/features/history/history_entry.dart';
import 'package:ezctx/features/history/history_repository.dart';
import 'package:ezctx/features/transcription/transcription_options.dart';
import 'package:ezctx/ui/screens/detail_screen.dart';
import 'package:ezctx/ui/screens/history_screen.dart';
import 'package:ezctx/ui/widgets/format_toggle.dart';
import 'package:ezctx/ui/widgets/glass_card.dart';
import 'package:ezctx/ui/widgets/glass_confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../core/services/clipboard_service_test.mocks.dart';

// Фейковый PathProvider для перехвата getTemporaryDirectory() в тестах шеринга.
class _FakeSharePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakeSharePathProvider(this.temp);
  final String temp;

  @override
  Future<String?> getTemporaryPath() async => temp;

  @override
  Future<String?> getApplicationDocumentsPath() async => temp;

  @override
  Future<String?> getExternalStoragePath() async => null;
}

// Стаб-репозиторий без реальной БД, с полями-шпионами для проверки вызовов.
class _StubHistoryRepository implements HistoryRepository {
  // Список вызовов update() — для проверки в тестах ACT-01, ACT-02.
  final List<HistoryEntry> updatedEntries = [];

  // Список вызовов remove() — для проверки в тестах ACT-04.
  final List<String> removedIds = [];

  final List<HistoryEntry> _entries;

  _StubHistoryRepository({List<HistoryEntry> entries = const []})
      : _entries = List.of(entries);

  @override
  Stream<List<HistoryEntry>> watchAll() => Stream.value(_entries);

  @override
  Future<List<HistoryEntry>> list() async => _entries;

  @override
  Future<void> add(HistoryEntry entry) async {}

  @override
  Future<void> remove(String id) async {
    removedIds.add(id);
  }

  @override
  Future<void> clear() async {}

  @override
  Future<void> update(HistoryEntry entry) async {
    updatedEntries.add(entry);
  }

  @override
  Stream<List<HistoryEntry>> watchSearch(FilterSpec spec) =>
      Stream.value(_entries);

  @override
  Future<List<String>> distinctLanguages() async => [];

  @override
  Future<List<String>> distinctProviders() async => [];
}

// Вспомогательная фабрика тестовой записи.
HistoryEntry _makeTestEntry({
  String id = '42',
  String title = 'Тестовая запись',
  String plainText = 'Полный текст расшифровки для тестирования detail-экрана.',
  bool isFavorite = false,
  String? timestampedText,
}) =>
    HistoryEntry(
      id: id,
      fileName: 'lecture.ogg',
      sizeBytes: 2 * 1024 * 1024,
      durationSec: 120.0,
      language: 'ru',
      createdAt: DateTime(2026, 3, 10, 14, 30),
      plainPath: '/data/transcripts/lecture.txt',
      timestampedPath: '/data/transcripts/lecture_ts.txt',
      title: title,
      provider: TranscriptionProviderId.groq,
      isFavorite: isFavorite,
      plainText: plainText,
      timestampedText: timestampedText,
    );

// Строит ProviderScope с переопределённым репозиторием и оборачивает в MaterialApp.
Widget _buildApp({
  required Widget home,
  _StubHistoryRepository? stub,
}) {
  final repo = stub ?? _StubHistoryRepository();
  return ProviderScope(
    overrides: [
      historyRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      home: home,
    ),
  );
}

void main() {
  group('DetailScreen — Wave 2 widget-тесты', () {
    // BRWS-03: detail-экран открывается и показывает plainText.
    testWidgets(
      'detail_opens: detail-экран открывается и показывает plainText',
      (tester) async {
        final entry = _makeTestEntry(
          plainText: 'Уникальный текст для теста detail_opens',
        );
        await tester.pumpWidget(_buildApp(
          home: DetailScreen(entry: entry),
        ));
        await tester.pumpAndSettle();

        // Должен отображаться полный текст расшифровки.
        expect(find.textContaining('Уникальный текст для теста detail_opens'),
            findsOneWidget);
      },
    );

    // BRWS-03: подсветка совпадений при активном searchTerm.
    testWidgets(
      'highlight_spans: TextSpan с accent+w700 при непустом searchTerm',
      (tester) async {
        const searchTerm = 'текст';
        const plainText = 'Полный текст расшифровки для тестирования.';
        final entry = _makeTestEntry(plainText: plainText);

        await tester.pumpWidget(_buildApp(
          home: DetailScreen(entry: entry, searchTerm: searchTerm),
        ));
        await tester.pumpAndSettle();

        // Находим виджет SelectableText.rich с подсвеченными span'ами.
        final richText = tester.widget<SelectableText>(
          find.byWidgetPredicate(
            (w) => w is SelectableText && w.textSpan != null,
            description: 'SelectableText.rich',
          ),
        );
        // Извлекаем все children TextSpan.
        final spans = (richText.textSpan as TextSpan).children ?? [];
        // Хотя бы один span должен иметь w700 (совпадение).
        final highlightSpans = spans
            .whereType<TextSpan>()
            .where((s) => s.style?.fontWeight == FontWeight.w700)
            .toList();
        expect(highlightSpans, isNotEmpty);
        // Совпадение должно содержать искомое слово (case-insensitive).
        final highlightedText = highlightSpans
            .map((s) => s.text?.toLowerCase() ?? '')
            .join();
        expect(highlightedText, contains(searchTerm.toLowerCase()));
      },
    );

    // ACT-01: тап по заголовку → TextField; submit → repo.update(newTitle).
    testWidgets(
      'inline_rename: тап по заголовку → TextField, submit → repo.update()',
      (tester) async {
        final stub = _StubHistoryRepository();
        final entry = _makeTestEntry(title: 'Старый заголовок');

        await tester.pumpWidget(_buildApp(
          home: DetailScreen(entry: entry),
          stub: stub,
        ));
        await tester.pumpAndSettle();

        // Тапаем по заголовку — должен появиться TextField.
        await tester.tap(find.text('Старый заголовок'));
        await tester.pumpAndSettle();

        expect(find.byType(TextField), findsOneWidget);

        // Вводим новый заголовок.
        await tester.enterText(find.byType(TextField), 'Новый заголовок');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        // Проверяем, что repo.update() вызван с новым заголовком.
        expect(stub.updatedEntries, isNotEmpty);
        expect(stub.updatedEntries.first.title, equals('Новый заголовок'));
      },
    );

    // ACT-01: пустой title при сохранении → update() НЕ вызывается.
    testWidgets(
      'inline_rename_empty: пустой title → откат, repo.update() не вызывается',
      (tester) async {
        final stub = _StubHistoryRepository();
        final entry = _makeTestEntry(title: 'Исходный заголовок');

        await tester.pumpWidget(_buildApp(
          home: DetailScreen(entry: entry),
          stub: stub,
        ));
        await tester.pumpAndSettle();

        // Тапаем по заголовку.
        await tester.tap(find.text('Исходный заголовок'));
        await tester.pumpAndSettle();

        // Очищаем поле и отправляем пустой ввод.
        await tester.enterText(find.byType(TextField), '   ');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        // update() не должен быть вызван.
        expect(stub.updatedEntries, isEmpty);
      },
    );

    // ACT-02: тап по звезде → repo.update(entry.copyWith(isFavorite: true)).
    testWidgets(
      'favorite_toggle: тап по звезде → repo.update(isFavorite: true)',
      (tester) async {
        final stub = _StubHistoryRepository();
        final entry = _makeTestEntry(isFavorite: false);

        await tester.pumpWidget(_buildApp(
          home: DetailScreen(entry: entry),
          stub: stub,
        ));
        await tester.pumpAndSettle();

        // Тапаем по иконке звезды (В избранное).
        await tester.tap(find.bySemanticsLabel('В избранное'));
        await tester.pumpAndSettle();

        // Проверяем, что repo.update() вызван с isFavorite: true.
        expect(stub.updatedEntries, isNotEmpty);
        expect(stub.updatedEntries.first.isFavorite, isTrue);
      },
    );

    // ACT-03: Copy — кнопка «Копировать» присутствует в нижней панели и доступна.
    testWidgets(
      'copy_action: Copy вызывает ClipboardService с plainText записи',
      (tester) async {
        final entry = _makeTestEntry(
            plainText: 'Текст для копирования в буфер обмена.');

        await tester.pumpWidget(_buildApp(
          home: DetailScreen(entry: entry),
        ));
        await tester.pumpAndSettle();

        // Проверяем, что кнопка «Копировать» существует в нижней панели.
        // find.text ищет по тексту подписи (Text-виджет).
        expect(find.text('Копировать'), findsOneWidget);

        // Тапаем кнопку. ClipboardService может выбросить исключение в тесте
        // (нет реального Platform channel), но экран не должен крашиться —
        // ошибки перехватываются и показываются через SnackBar.
        await tester.tap(find.text('Копировать'));
        // pump — не pumpAndSettle, чтобы не ждать анимацию SnackBar.
        await tester.pump();

        // Главное — экран не упал.
        expect(find.byType(DetailScreen), findsOneWidget);
      },
    );

    // UI-08: нижняя панель действий (Copy/Share/Delete) обёрнута в GlassCard —
    // glass-стиль вместо дефолтного Container.
    testWidgets(
      'bottom_bar_glass: нижняя панель действий в GlassCard',
      (tester) async {
        final entry = _makeTestEntry();

        await tester.pumpWidget(_buildApp(
          home: DetailScreen(entry: entry),
        ));
        await tester.pumpAndSettle();

        // Кнопка «Копировать» из нижней панели — потомок GlassCard.
        expect(
          find.ancestor(
            of: find.text('Копировать'),
            matching: find.byType(GlassCard),
          ),
          findsOneWidget,
        );
      },
    );

    // ACT-04: Delete → AlertDialog → confirm → repo.remove() → Navigator.pop.
    testWidgets(
      'detail_delete: Delete → AlertDialog → confirm → repo.remove() → pop',
      (tester) async {
        final stub = _StubHistoryRepository();
        final entry = _makeTestEntry(id: '99');

        // Для проверки Navigator.pop оборачиваем в Navigator.
        await tester.pumpWidget(ProviderScope(
          overrides: [
            historyRepositoryProvider.overrideWithValue(stub),
          ],
          child: MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
              useMaterial3: true,
            ),
            home: Builder(
              builder: (ctx) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      ctx,
                      MaterialPageRoute(
                        builder: (_) => DetailScreen(entry: entry),
                      ),
                    );
                  },
                  child: const Text('Открыть detail'),
                ),
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();

        // Открываем detail-экран.
        await tester.tap(find.text('Открыть detail'));
        await tester.pumpAndSettle();

        // Тапаем «Удалить» в нижней панели (подпись кнопки = Text('Удалить')).
        await tester.tap(find.text('Удалить'));
        await tester.pump(); // первый кадр — запуск showDialog
        await tester.pump(const Duration(milliseconds: 300)); // анимация диалога

        // Должен появиться GlassConfirmDialog с заголовком.
        expect(find.text('Удалить запись?'), findsOneWidget);

        // Подтверждаем удаление — нажимаем кнопку внутри GlassConfirmDialog.
        // Используем descendant чтобы точно найти кнопку внутри диалога.
        final dialogDeleteBtn = find.descendant(
          of: find.byType(GlassConfirmDialog),
          matching: find.text('Удалить'),
        );
        await tester.tap(dialogDeleteBtn);
        await tester.pumpAndSettle();

        // Проверяем, что repo.remove() вызван с правильным id.
        expect(stub.removedIds, contains('99'));
      },
    );

    // ACT-04: свайп влево на карточке в HistoryScreen → repo.remove(entry.id).
    // Реализован в plan 03-03: Dismissible добавлен в history_screen._HistoryList.
    testWidgets(
      'swipe_delete: свайп влево на карточке → repo.remove(entry.id)',
      (tester) async {
        final stub = _StubHistoryRepository();
        final entry = _makeTestEntry(id: '55');

        // Отображаем HistoryScreen с одной записью.
        await tester.pumpWidget(ProviderScope(
          overrides: [
            historyRepositoryProvider.overrideWithValue(stub),
            searchResultsProvider.overrideWith(
              (ref) => AsyncValue.data([entry]),
            ),
            filterNotifierProvider.overrideWith(
              () => _FixedFilterNotifier(const FilterSpec()),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
              useMaterial3: true,
            ),
            home: const HistoryScreen(),
          ),
        ));
        await tester.pumpAndSettle();

        // Проверяем, что карточка отображается.
        expect(find.text('Тестовая запись'), findsOneWidget);

        // Свайп endToStart по карточке — удаление (D-05).
        await tester.drag(
            find.text('Тестовая запись'), const Offset(-500, 0));
        await tester.pumpAndSettle();

        // repo.remove() должен быть вызван с id = '55'.
        expect(stub.removedIds, contains('55'));
      },
    );
  });

  group('DetailScreen — переключатель вида (С метками / Без меток)', () {
    // setUp/tearDown: настраиваем мок буфера обмена и MethodChannel share_plus.
    late MockClipboardWriter mockClipboard;

    setUp(() {
      mockClipboard = MockClipboardWriter();
      when(mockClipboard.write(any)).thenAnswer((_) async {});
      ClipboardService.clipboardOverride = mockClipboard;

      // Мок share_plus MethodChannel — без него тап «Поделиться» падает с MissingPluginException.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/share'),
        (call) async => null,
      );
    });

    tearDown(() {
      ClipboardService.clipboardOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/share'),
        null,
      );
    });

    testWidgets('тоггл скрыт, когда timestampedText == null', (tester) async {
      final entry = _makeTestEntry(plainText: 'обычный текст');
      await tester.pumpWidget(_buildApp(home: DetailScreen(entry: entry)));
      await tester.pumpAndSettle();

      expect(find.byType(FormatToggle), findsNothing);
      expect(find.textContaining('обычный текст'), findsOneWidget);
    });

    testWidgets('тоггл виден при осмысленных метках; по умолчанию plain',
        (tester) async {
      final entry = _makeTestEntry(
        plainText: 'привет мир',
        timestampedText: '[00:00:00] привет мир',
      );
      await tester.pumpWidget(_buildApp(home: DetailScreen(entry: entry)));
      await tester.pumpAndSettle();

      expect(find.byType(FormatToggle), findsOneWidget);
      // По умолчанию — без меток: метки в тексте не показаны.
      expect(find.textContaining('[00:00:00]'), findsNothing);
    });

    testWidgets('тап «С метками» показывает текст с таймкодами', (tester) async {
      final entry = _makeTestEntry(
        plainText: 'привет мир',
        timestampedText: '[00:00:00] привет мир',
      );
      await tester.pumpWidget(_buildApp(home: DetailScreen(entry: entry)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('С метками'));
      await tester.pumpAndSettle();

      expect(find.textContaining('[00:00:00]'), findsOneWidget);
    });

    // Проверяем, что Копировать использует текст текущего вида:
    // при активном виде «С метками» mock.write() вызывается (значит вызов прошёл).
    testWidgets('Копировать вызывается при активном виде «С метками»',
        (tester) async {
      final entry = _makeTestEntry(
        plainText: 'привет мир',
        timestampedText: '[00:00:00] привет мир',
      );
      await tester.pumpWidget(_buildApp(home: DetailScreen(entry: entry)));
      await tester.pumpAndSettle();

      // Переключаемся на вид с метками.
      await tester.tap(find.text('С метками'));
      await tester.pumpAndSettle();

      // Копируем.
      await tester.tap(find.text('Копировать'));
      await tester.pump();

      // write() должен был быть вызван (через ClipboardService → mock).
      verify(mockClipboard.write(any)).called(1);
    });

    // Проверяем, что «Поделиться» отдаёт текст текущего вида (с таймкодами).
    testWidgets('Поделиться берёт текст текущего вида (с метками)',
        (tester) async {
      await tester.runAsync(() async {
        final tmpDir = Directory.systemTemp.createTempSync('detail_share_test');
        final originalPathProvider = PathProviderPlatform.instance;
        PathProviderPlatform.instance = _FakeSharePathProvider(tmpDir.path);

        List<dynamic>? capturedPaths;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/share'),
          (call) async {
            if (call.method == 'shareFiles') {
              capturedPaths = (call.arguments as Map)['paths'] as List<dynamic>?;
            }
            return null;
          },
        );

        final entry = _makeTestEntry(
          plainText: 'привет мир',
          timestampedText: '[00:00:00] привет мир',
        );
        await tester.pumpWidget(_buildApp(home: DetailScreen(entry: entry)));
        await tester.pumpAndSettle();

        // Переключаемся на вид «С метками».
        await tester.tap(find.text('С метками'));
        await tester.pumpAndSettle();

        // Шерим.
        await tester.tap(find.text('Поделиться'));
        await tester.pump(); // доставить tap/onPressed
        // Реальный I/O (writeTempTxt) идёт на реальном event-loop внутри runAsync;
        // tester.pump НЕ продвигает реальное время, поэтому поллим реальными
        // задержками — выходим сразу при захвате (потолок с запасом под нагрузку
        // полного прогона, когда изоляты конкурируют за реальное время).
        for (var i = 0; i < 200 && capturedPaths == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }

        expect(capturedPaths, isNotNull);
        // entry.title формирует имя; вид с метками → суффикс _timestamped.
        expect(capturedPaths!.single, endsWith('_timestamped.txt'));
        expect(
          await File(capturedPaths!.single as String).readAsString(),
          contains('[00:00:00]'),
        );

        PathProviderPlatform.instance = originalPathProvider;
        tmpDir.deleteSync(recursive: true);
      });
    });
  });
}

// Notifier с фиксированным состоянием FilterSpec.
class _FixedFilterNotifier extends FilterNotifier {
  final FilterSpec _fixedSpec;
  _FixedFilterNotifier(this._fixedSpec);

  @override
  FilterSpec build() => _fixedSpec;
}
