import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/repository_providers.dart';
import 'core/providers/service_providers.dart';
import 'features/transcription/key_pool.dart';
import 'ui/app.dart';

// Точка входа приложения: через временный ProviderContainer читает ключи из
// обоих репозиториев (Groq + Deepgram), формирует два KeyPool,
// после чего стартует UI с переопределёнными groqKeyPoolProvider и
// deepgramKeyPoolProvider. ApiKeyRepository stateless — повторное создание
// провайдером в основном ProviderScope безопасно.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final bootstrap = ProviderContainer();

  // Читаем ключи обоих провайдеров до dispose контейнера.
  final groqRawKeys = await bootstrap.read(apiKeyRepoProvider).listKeys();
  final deepgramRawKeys =
      await bootstrap.read(deepgramApiKeyRepoProvider).listKeys();

  bootstrap.dispose();

  // Groq KeyPool.
  final groqKeyPool = KeyPool(
    initialKeys: groqRawKeys.map((k) => k.raw).toList(),
  );

  // Deepgram KeyPool.
  final deepgramKeyPool = KeyPool(
    initialKeys: deepgramRawKeys.map((k) => k.raw).toList(),
  );

  runApp(
    ProviderScope(
      overrides: [
        groqKeyPoolProvider.overrideWithValue(groqKeyPool),
        deepgramKeyPoolProvider.overrideWithValue(deepgramKeyPool),
      ],
      child: const EzCtxApp(),
    ),
  );
}
