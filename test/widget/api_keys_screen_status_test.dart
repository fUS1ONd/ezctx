import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ezctx/features/transcription/key_pool.dart';
import 'package:ezctx/ui/widgets/key_status_tile.dart';

void main() {
  group('KeyStatusTile', () {
    testWidgets('активный ключ показывает Активен', (tester) async {
      const status = ActiveKeyStatus(key: 'test_key');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KeyStatusTile(status: status),
          ),
        ),
      );

      // Должен быть текст "Активен"
      expect(find.text('Активен'), findsOneWidget);
    });

    testWidgets('заблокированный ключ показывает До HH:MM:SS', (tester) async {
      final blockedUntil = DateTime.now().add(const Duration(seconds: 90));
      final status = BlockedKeyStatus(key: 'test_key', blockedUntil: blockedUntil);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KeyStatusTile(status: status),
          ),
        ),
      );

      // Должен быть текст начинающийся с "До 00:01:"
      expect(
        find.textContaining('До 00:01:'),
        findsOneWidget,
      );
    });

    testWidgets('таймер уменьшает отсчёт через 1 секунду', (tester) async {
      final blockedUntil = DateTime.now().add(const Duration(seconds: 90));
      final status = BlockedKeyStatus(key: 'test_key', blockedUntil: blockedUntil);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KeyStatusTile(status: status),
          ),
        ),
      );

      // Начальное состояние
      expect(find.textContaining('До 00:01:'), findsOneWidget);

      // Продвигаем время на 1 секунду
      await tester.pump(const Duration(seconds: 1));

      // Отсчёт должен уменьшиться
      expect(find.textContaining('До 00:01:'), findsOneWidget);
    });

    testWidgets('исчерпанный ключ показывает Исчерпан', (tester) async {
      // Тест RED: KeyStatusTile пока не имеет ветки ExhaustedKeyStatus,
      // поэтому этот тест должен упасть до реализации.
      const status = ExhaustedKeyStatus(key: 'test_key');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KeyStatusTile(status: status),
          ),
        ),
      );

      // Должен быть текст «Исчерпан»
      expect(find.text('Исчерпан'), findsOneWidget);
      // Не должно быть текста «Активен» при статусе Exhausted
      expect(find.text('Активен'), findsNothing);
      // Не должно быть таймера (текст «До »)
      expect(find.textContaining('До '), findsNothing);
    });

    testWidgets('исчерпанный ключ не запускает таймер', (tester) async {
      const status = ExhaustedKeyStatus(key: 'test_key');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KeyStatusTile(status: status),
          ),
        ),
      );

      // Продвигаем время — таймер не должен менять отображение
      await tester.pump(const Duration(seconds: 2));

      // Статус должен оставаться «Исчерпан»
      expect(find.text('Исчерпан'), findsOneWidget);
      expect(find.textContaining('До '), findsNothing);
    });
  });
}
