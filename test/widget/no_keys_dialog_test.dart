import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ezctx/ui/widgets/no_keys_dialog.dart';

void main() {
  group('NoKeysDialog', () {
    testWidgets('Groq-дефолт: заголовок «Нужен ключ Groq» виден', (tester) async {
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

    testWidgets('Deepgram-вариант: заголовок «Нужен ключ Deepgram» виден', (tester) async {
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
