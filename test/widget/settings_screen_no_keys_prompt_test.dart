// Widget-тест симметричного предупреждения «Нужен ключ» в SettingsScreen.
//
// Проверяет, что диалог об отсутствующем ключе показывается для ЛЮБОГО
// провайдера выбранной модели (а не только Deepgram/nova3):
//  • выбор Whisper (Groq) при 0 ключей Groq → диалог «Нужен ключ Groq»;
//  • выбор Nova-3 (Deepgram) при 0 ключей Deepgram → диалог «Нужен ключ Deepgram»;
//  • выбор модели при наличии ключа провайдера → диалога нет.

import 'package:ezctx/core/providers/repository_providers.dart';
import 'package:ezctx/core/providers/service_providers.dart';
import 'package:ezctx/core/providers/theme_provider.dart';
import 'package:ezctx/features/settings/transcription_options_repository.dart';
import 'package:ezctx/features/transcription/key_pool.dart';
import 'package:ezctx/features/transcription/transcription_options.dart';
import 'package:ezctx/ui/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Заглушка темы — не обращается к flutter_secure_storage.
class _FakeThemeModeNotifier extends ThemeModeNotifier {
  @override
  ThemeMode build() => ThemeMode.light;
}

// Фейковый репозиторий настроек — дефолтные опции, save — no-op.
class _FakeOptionsRepo extends TranscriptionOptionsRepository {
  @override
  Future<TranscriptionOptions> load() async =>
      const TranscriptionOptions.defaults();

  @override
  Future<void> save(TranscriptionOptions options) async {}
}

/// Задаём viewport телефона чтобы избежать overflow.
void _setPhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Поднимает SettingsScreen с заданными пулами ключей.
Future<void> _pumpSettings(
  WidgetTester tester, {
  required List<String> groqKeys,
  required List<String> deepgramKeys,
}) async {
  _setPhoneViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        groqKeyPoolProvider.overrideWithValue(
          KeyPool(initialKeys: groqKeys),
        ),
        deepgramKeyPoolProvider.overrideWithValue(
          KeyPool(initialKeys: deepgramKeys),
        ),
        transcriptionOptionsRepoProvider.overrideWithValue(_FakeOptionsRepo()),
        themeModeProvider.overrideWith(_FakeThemeModeNotifier.new),
      ],
      child: const MaterialApp(home: SettingsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

/// Открывает пикер моделей и выбирает модель по её метке.
Future<void> _pickModel(WidgetTester tester, String label) async {
  await tester.tap(find.text('Модель'));
  await tester.pumpAndSettle();
  // В пикере метка модели присутствует; берём последнюю (строка в bottom-sheet).
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  group('SettingsScreen — симметричное предупреждение о ключе', () {
    testWidgets(
      'выбор Whisper при 0 ключей Groq → диалог «Нужен ключ Groq»',
      (tester) async {
        await _pumpSettings(tester, groqKeys: const [], deepgramKeys: const []);

        await _pickModel(tester, 'Whisper Turbo');

        expect(find.text('Нужен ключ Groq'), findsOneWidget);
        expect(find.text('Нужен ключ Deepgram'), findsNothing);
      },
    );

    testWidgets(
      'выбор Nova-3 при 0 ключей Deepgram → диалог «Нужен ключ Deepgram»',
      (tester) async {
        await _pumpSettings(tester, groqKeys: const [], deepgramKeys: const []);

        await _pickModel(tester, 'Nova-3');

        expect(find.text('Нужен ключ Deepgram'), findsOneWidget);
        expect(find.text('Нужен ключ Groq'), findsNothing);
      },
    );

    testWidgets(
      'выбор Whisper при наличии ключа Groq → диалога нет',
      (tester) async {
        await _pumpSettings(
          tester,
          groqKeys: const ['gsk_fake_key'],
          deepgramKeys: const [],
        );

        await _pickModel(tester, 'Whisper Turbo');

        expect(find.text('Нужен ключ Groq'), findsNothing);
      },
    );
  });
}
