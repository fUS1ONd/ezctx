import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ezctx/ui/widgets/no_keys_dialog.dart';

/// Задаём размер экрана 800×1200 логических пикселей,
/// чтобы PrimaryButton внутри диалога не переполнялся по ширине.
void _setPhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('NoKeysDialog', () {
    testWidgets('Groq-дефолт: заголовок «Нужен ключ Groq» виден', (tester) async {
      _setPhoneViewport(tester);
      // Без параметров — должны применяться Groq-дефолты
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => NoKeysDialog.show(ctx),
              child: const Text('Открыть диалог'),
            ),
          ),
        ),
      );

      // Нажимаем кнопку-триггер для показа диалога
      await tester.tap(find.text('Открыть диалог'));
      await tester.pumpAndSettle();

      // Проверяем заголовок Groq по умолчанию
      expect(find.text('Нужен ключ Groq'), findsOneWidget);
    });

    testWidgets('заголовок под Material (нет жёлтого подчёркивания)', (tester) async {
      // Регрессия: контент showGeneralDialog лежит вне Scaffold, без предка
      // Material Text рисуется жёлтым с двойным подчёркиванием. Проверка
      // падала бы до фикса.
      _setPhoneViewport(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => NoKeysDialog.show(ctx),
              child: const Text('Открыть диалог'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Открыть диалог'));
      await tester.pumpAndSettle();

      expect(
        find.ancestor(
          of: find.text('Нужен ключ Groq'),
          matching: find.byType(Material),
        ),
        findsWidgets,
      );
    });

    testWidgets('Deepgram-вариант: заголовок «Нужен ключ Deepgram» виден', (tester) async {
      _setPhoneViewport(tester);
      // Передаём Deepgram-параметры
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => NoKeysDialog.show(
                ctx,
                title: 'Нужен ключ Deepgram',
                bodyText:
                    'Nova-3 работает через Deepgram. Добавьте API-ключ Deepgram — free-tier хватает на часы аудио.',
              ),
              child: const Text('Открыть диалог'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Открыть диалог'));
      await tester.pumpAndSettle();

      // Groq-заголовка быть не должно, Deepgram — должен быть
      expect(find.text('Нужен ключ Groq'), findsNothing);
      expect(find.text('Нужен ключ Deepgram'), findsOneWidget);
    });

    testWidgets('onOpenSettings callback вызывается при нажатии «Открыть настройки»',
        (tester) async {
      _setPhoneViewport(tester);
      // Флаг для проверки вызова callback
      var called = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => NoKeysDialog.show(
                ctx,
                onOpenSettings: () => called = true,
              ),
              child: const Text('Открыть диалог'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Открыть диалог'));
      await tester.pumpAndSettle();

      // Нажимаем кнопку «Открыть настройки» внутри диалога
      await tester.tap(find.text('Открыть настройки'));
      await tester.pumpAndSettle();

      // Callback должен был вызваться
      expect(called, isTrue);
    });
  });
}
