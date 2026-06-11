// test/widget/api_keys_screen_tabs_test.dart
//
// Widget-тесты для ApiKeysScreen: вкладки Groq/Deepgram, initialTab, переключение.

import 'package:ezctx/core/providers/repository_providers.dart';
import 'package:ezctx/core/providers/service_providers.dart';
import 'package:ezctx/core/providers/storage_providers.dart';
import 'package:ezctx/core/storage/secure_storage_service.dart';
import 'package:ezctx/features/transcription/key_pool.dart';
import 'package:ezctx/ui/screens/api_keys_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Фейковый SecureStorageService — не обращается к flutter_secure_storage.
// Используем чтобы изолировать тест от реального хранилища устройства.
class _FakeSecureStorage implements SecureStorageService {
  @override
  Future<void> writeRawKey(String value) async {}

  @override
  Future<String?> readRawKey() async => null;

  @override
  Future<void> deleteRawKey() async {}

  @override
  Future<List<String>> listApiKeys() async => [];

  @override
  Future<void> addApiKey(String key) async {}

  @override
  Future<void> removeApiKey(String key) async {}
}

// Синглтон фейкового хранилища — переиспользуется для обоих провайдеров
final _fakeStorage = _FakeSecureStorage();

/// Строит дерево виджетов с ProviderScope, переопределяя все провайдеры-зависимости.
///
/// Оба пула ключей переопределяются через overrideWithValue (пустой KeyPool).
/// Оба storage-провайдера переопределяются фейком — без SecureStorage.
/// Выбор: переопределяем storage-провайдеры, а не repo-провайдеры,
/// чтобы тест максимально проверял реальный код ApiKeyRepository.
Widget _wrap(Widget child) {
  return ProviderScope(
    overrides: [
      // Переопределяем пулы ключей — иначе провайдеры бросают UnimplementedError
      groqKeyPoolProvider.overrideWithValue(KeyPool(initialKeys: const [])),
      deepgramKeyPoolProvider.overrideWithValue(KeyPool(initialKeys: const [])),
      // Переопределяем хранилища — изолируем от реального flutter_secure_storage
      secureStorageProvider.overrideWithValue(_fakeStorage),
      deepgramSecureStorageProvider.overrideWithValue(_fakeStorage),
    ],
    child: MaterialApp(home: child),
  );
}

/// Задаём viewport телефона (390×844), чтобы избежать layout overflow.
void _setPhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('ApiKeysScreen tabs', () {
    testWidgets('дефолтный экран показывает обе вкладки Groq и Deepgram', (tester) async {
      _setPhoneViewport(tester);

      // Рендерим экран с дефолтным initialTab='groq'
      await tester.pumpWidget(_wrap(const ApiKeysScreen()));
      await tester.pumpAndSettle();

      // Обе вкладки должны быть видны в таббаре
      expect(find.text('Groq'), findsWidgets);
      expect(find.text('Deepgram'), findsWidgets);

      // Никаких исключений при рендере
      expect(tester.takeException(), isNull);
    });

    testWidgets('initialTab="groq" — активна Groq-вкладка, hint содержит gsk_',
        (tester) async {
      _setPhoneViewport(tester);

      await tester.pumpWidget(
        _wrap(const ApiKeysScreen(initialTab: 'groq')),
      );
      await tester.pumpAndSettle();

      // Groq-вкладка активна — её hint-текст с префиксом gsk_ виден
      expect(find.textContaining('gsk_'), findsOneWidget);
    });

    testWidgets('initialTab="deepgram" — активна Deepgram-вкладка при старте',
        (tester) async {
      _setPhoneViewport(tester);

      await tester.pumpWidget(
        _wrap(const ApiKeysScreen(initialTab: 'deepgram')),
      );
      await tester.pumpAndSettle();

      // Deepgram-вкладка активна — ссылка на deepgram.com видна
      expect(find.textContaining('deepgram.com'), findsOneWidget);
      // Groq-специфичный hint не должен быть виден
      expect(find.textContaining('gsk_'), findsNothing);
    });

    testWidgets('tap по вкладке Deepgram переключает контент на Deepgram',
        (tester) async {
      _setPhoneViewport(tester);

      // Стартуем с Groq-вкладки
      await tester.pumpWidget(
        _wrap(const ApiKeysScreen(initialTab: 'groq')),
      );
      await tester.pumpAndSettle();

      // Изначально виден Groq-hint
      expect(find.textContaining('gsk_'), findsOneWidget);

      // Тапаем по вкладке Deepgram — первое вхождение текста 'Deepgram'
      // (в таббаре; может быть и в контенте, поэтому берём first)
      final deepgramTab = find.text('Deepgram').first;
      await tester.tap(deepgramTab);
      await tester.pumpAndSettle();

      // После переключения — виден Deepgram-hint, Groq-hint исчез
      expect(find.textContaining('gsk_'), findsNothing);
      expect(find.textContaining('deepgram.com'), findsOneWidget);
    });
  });
}
