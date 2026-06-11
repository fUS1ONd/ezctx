import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ezctx/ui/widgets/liquid_glass_tab_bar.dart';

void main() {
  group('LiquidGlassTabBar — text-only вкладки', () {
    testWidgets('text-only TabBar рендерится без ошибок', (tester) async {
      // Тест RED: TabItem сейчас требует icon (required), поэтому не компилируется
      // без icon. После сделать nullable — тест должен пройти.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiquidGlassTabBar(
              activeIndex: 0,
              onChanged: (_) {},
              items: const [
                TabItem(label: 'Groq'),
                TabItem(label: 'Deepgram'),
              ],
            ),
          ),
        ),
      );

      // Виден текст обеих вкладок
      expect(find.text('Groq'), findsOneWidget);
      expect(find.text('Deepgram'), findsOneWidget);
    });

    testWidgets('text-only TabBar — тексты видны без ошибок рендеринга', (tester) async {
      // Проверяем, что text-only вкладки рендерятся без исключений.
      // CustomPaint не проверяем напрямую — BackdropFilter создаёт свой CustomPaint;
      // ключевой признак — виден текст и нет ошибок.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiquidGlassTabBar(
              activeIndex: 0,
              onChanged: (_) {},
              items: const [
                TabItem(label: 'Groq'),
                TabItem(label: 'Deepgram'),
              ],
            ),
          ),
        ),
      );

      // Тексты присутствуют
      expect(find.text('Groq'), findsOneWidget);
      expect(find.text('Deepgram'), findsOneWidget);
      // Нет ни одного текста с именами навигационных вкладок (нет путаницы)
      expect(find.text('Главная'), findsNothing);
    });

    testWidgets('регрессия: вкладки с иконками рендерятся корректно', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiquidGlassTabBar(
              activeIndex: 0,
              onChanged: (_) {},
              // Дефолтные вкладки с иконками — обратная совместимость
              items: const [
                TabItem(label: 'Главная', icon: TabIconKind.home),
                TabItem(label: 'История', icon: TabIconKind.doc),
                TabItem(label: 'Настройки', icon: TabIconKind.gear),
              ],
            ),
          ),
        ),
      );

      // Тексты навигационных вкладок видны
      expect(find.text('Главная'), findsOneWidget);
      expect(find.text('История'), findsOneWidget);
      expect(find.text('Настройки'), findsOneWidget);
    });
  });
}
