// Widget-тест пикера моделей в SettingsScreen.
//
// Проверяет что Nova-3 видна в списке моделей (D-14: убран фильтр nova3).

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

// Фейковый репозиторий настроек — возвращает дефолтные опции.
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

void main() {
  group('SettingsScreen пикер моделей', () {
    testWidgets('открытие пикера — Nova-3 видна в списке', (tester) async {
      _setPhoneViewport(tester);

      // Оборачиваем в ProviderScope с переопределёнными провайдерами
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Переопределяем оба пула ключей — без UnimplementedError
            groqKeyPoolProvider.overrideWithValue(
              KeyPool(initialKeys: const []),
            ),
            deepgramKeyPoolProvider.overrideWithValue(
              KeyPool(initialKeys: const []),
            ),
            // Фейковый репо — без flutter_secure_storage
            transcriptionOptionsRepoProvider
                .overrideWithValue(_FakeOptionsRepo()),
            // Фейковая тема
            themeModeProvider.overrideWith(_FakeThemeModeNotifier.new),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Тапаем по строке «Модель» чтобы открыть пикер
      await tester.tap(find.text('Модель'));
      await tester.pumpAndSettle();

      // D-14: nova3 убрана из фильтра — «Nova-3» должна присутствовать в списке
      expect(find.text('Nova-3'), findsWidgets);

      // Остальные модели тоже присутствуют
      expect(find.textContaining('Whisper'), findsWidgets);
    });
  });
}
