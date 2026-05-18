import 'package:flutter/material.dart';

import 'core/storage/secure_storage_service.dart';
import 'features/settings/api_key_repository.dart';
import 'features/transcription/groq_key_pool.dart';
import 'ui/app.dart';

// Точка входа приложения: инициализирует GroqKeyPool с ключами из SecureStorage,
// затем запускает корневой виджет EzCtxApp.
void main() async {
  // Необходимо перед любыми async-вызовами (flutter_secure_storage, path_provider).
  WidgetsFlutterBinding.ensureInitialized();

  // Загружаем ключи из защищённого хранилища для инициализации пула.
  final repository = ApiKeyRepository(SecureStorageServiceImpl());
  final rawKeys = await repository.listKeys();

  // Создаём singleton GroqKeyPool — передаётся в оба контроллера транскрибации.
  final groqKeyPool = GroqKeyPool(
    initialKeys: rawKeys.map((k) => k.raw).toList(),
  );

  runApp(EzCtxApp(groqKeyPool: groqKeyPool));
}
