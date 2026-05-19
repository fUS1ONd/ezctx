import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/service_providers.dart';
import 'core/storage/secure_storage_service.dart';
import 'features/settings/api_key_repository.dart';
import 'features/transcription/groq_key_pool.dart';
import 'ui/app.dart';

// Точка входа приложения: инициализирует GroqKeyPool с ключами из SecureStorage,
// затем запускает корневой виджет в ProviderScope.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final repository = ApiKeyRepository(SecureStorageServiceImpl());
  final rawKeys = await repository.listKeys();

  final groqKeyPool = GroqKeyPool(
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
