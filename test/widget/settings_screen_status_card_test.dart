// Widget-тесты мультипровайдерной StatusCard в SettingsScreen.
//
// Проверяет:
//  1. Whisper-модель + 1 живой Groq-ключ → «Groq · 1 ключ · Подключено»
//  2. Nova-3 + пустой Deepgram-пул → «Nova-3 · Deepgram · Нет ключей»

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

// Фейковый репозиторий настроек транскрибации — возвращает заданные опции.
class _FakeOptionsRepo extends TranscriptionOptionsRepository {
  final TranscriptionOptions _opts;
  _FakeOptionsRepo(this._opts);

  @override
  Future<TranscriptionOptions> load() async => _opts;

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

/// Строит SettingsScreen с заданными пулами ключей и начальными опциями.
Widget _wrap({
  required KeyPool groqPool,
  required KeyPool deepgramPool,
  TranscriptionOptions opts = const TranscriptionOptions.defaults(),
}) {
  return ProviderScope(
    overrides: [
      // Переопределяем оба пула — иначе UnimplementedError
      groqKeyPoolProvider.overrideWithValue(groqPool),
      deepgramKeyPoolProvider.overrideWithValue(deepgramPool),
      // Фейковый репо настроек — изолирует от реального SecureStorage
      transcriptionOptionsRepoProvider.overrideWithValue(_FakeOptionsRepo(opts)),
      // Фейковая тема — без SecureStorage
      themeModeProvider.overrideWith(_FakeThemeModeNotifier.new),
    ],
    child: const MaterialApp(home: SettingsScreen()),
  );
}

void main() {
  group('SettingsScreen StatusCard', () {
    testWidgets(
      'Whisper-модель + 1 Groq-ключ → «Groq · 1 ключ · Подключено»',
      (tester) async {
        _setPhoneViewport(tester);

        // Groq-пул с одним живым ключом
        final groqPool = KeyPool(initialKeys: const ['gsk_testkey_0000000001']);

        await tester.pumpWidget(
          _wrap(
            groqPool: groqPool,
            deepgramPool: KeyPool(initialKeys: const []),
            opts: const TranscriptionOptions(
              model: TranscriptionModel.whisperLargeV3,
              language: TranscriptionLanguage.auto,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Проверяем что строка статуса содержит «Groq» и «Подключено»
        expect(find.textContaining('Groq'), findsWidgets);
        expect(find.textContaining('Подключено'), findsOneWidget);
        // Проверяем плюрализацию «1 ключ»
        expect(find.textContaining('1 ключ'), findsWidgets);
      },
    );

    testWidgets(
      'Nova-3 + пустой Deepgram-пул → «Nova-3 · Deepgram · Нет ключей»',
      (tester) async {
        _setPhoneViewport(tester);

        await tester.pumpWidget(
          _wrap(
            groqPool: KeyPool(initialKeys: const []),
            deepgramPool: KeyPool(initialKeys: const []),
            opts: const TranscriptionOptions(
              model: TranscriptionModel.nova3,
              language: TranscriptionLanguage.auto,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Проверяем что видны «Nova-3» и «Нет ключей» в статус-карточке
        expect(find.textContaining('Nova-3'), findsWidgets);
        expect(find.textContaining('Нет ключей'), findsWidgets);
        expect(find.textContaining('Deepgram'), findsWidgets);
        // «Подключено» не должно быть
        expect(find.textContaining('Подключено'), findsNothing);
      },
    );

    testWidgets(
      'Nova-3 + 2 Deepgram-ключа → «Nova-3 · Deepgram · 2 ключа · Подключено»',
      (tester) async {
        _setPhoneViewport(tester);

        final deepgramPool = KeyPool(
          initialKeys: const ['dp_key_aaa', 'dp_key_bbb'],
        );

        await tester.pumpWidget(
          _wrap(
            groqPool: KeyPool(initialKeys: const []),
            deepgramPool: deepgramPool,
            opts: const TranscriptionOptions(
              model: TranscriptionModel.nova3,
              language: TranscriptionLanguage.auto,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Строка содержит «2 ключа» и «Подключено»
        expect(find.textContaining('2 ключа'), findsWidgets);
        expect(find.textContaining('Подключено'), findsOneWidget);
      },
    );
  });

  group('SettingsScreen _Row «API-ключи» — реактивность счётчика', () {
    testWidgets(
      'счётчик обновляется без setState когда pool.addKey вызывается после рендера',
      (tester) async {
        _setPhoneViewport(tester);

        // Пустой Groq-пул — счётчик «Нет ключей»
        final groqPool = KeyPool(initialKeys: const []);

        await tester.pumpWidget(
          _wrap(
            groqPool: groqPool,
            deepgramPool: KeyPool(initialKeys: const []),
            opts: const TranscriptionOptions(
              model: TranscriptionModel.whisperLargeV3,
              language: TranscriptionLanguage.auto,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Строка «API-ключи» показывает «Нет ключей» (точное совпадение,
        // в отличие от StatusCard которая показывает «Groq · Нет ключей»)
        expect(find.text('Нет ключей'), findsOneWidget);

        // Имитируем добавление ключа (как это делает ApiKeysScreen)
        groqPool.addKey('gsk_testkey_0000000001');
        await tester.pump();

        // Строка «API-ключи» должна обновиться реактивно без setState
        expect(find.text('Нет ключей'), findsNothing);
        expect(find.text('1 ключ'), findsOneWidget);
      },
    );
  });
}
