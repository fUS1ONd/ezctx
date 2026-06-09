import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/repository_providers.dart';
import 'core/providers/service_providers.dart';
import 'features/transcription/key_pool.dart';
import 'ui/app.dart';

// Точка входа приложения: через временный ProviderContainer читает ключи из
// apiKeyRepoProvider (единый источник истины), формирует KeyPool, после
// чего стартует UI с переопределённым groqKeyPoolProvider. ApiKeyRepository
// stateless — повторное создание провайдером в основном ProviderScope
// безопасно: оба инстанса читают одно и то же защищённое хранилище.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final bootstrap = ProviderContainer();
  final rawKeys = await bootstrap.read(apiKeyRepoProvider).listKeys();
  bootstrap.dispose();

  final groqKeyPool = KeyPool(
    initialKeys: rawKeys.map((k) => k.raw).toList(),
  );

  runApp(
    ProviderScope(
      overrides: [
        groqKeyPoolProvider.overrideWithValue(groqKeyPool),
      ],
      child: const EzCtxApp(),
    ),
  );
}
