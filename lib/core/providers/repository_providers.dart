import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/api_key_repository.dart';
import '../../features/settings/transcription_options_repository.dart';
import 'storage_providers.dart';

/// Репозиторий Groq API-ключей (namespace: groq_api_keys_v1).
final apiKeyRepoProvider = Provider<ApiKeyRepository>(
  (ref) => ApiKeyRepository(ref.watch(secureStorageProvider)),
);

final transcriptionOptionsRepoProvider = Provider<TranscriptionOptionsRepository>(
  (ref) => TranscriptionOptionsRepository(),
);

/// Реактивный список Groq-ключей для баннера на HomeScreen.
final apiKeysProvider = FutureProvider<List<ApiKeyView>>((ref) async {
  return ref.watch(apiKeyRepoProvider).listKeys();
});

/// Репозиторий Deepgram API-ключей (namespace: deepgram_api_keys_v1).
final deepgramApiKeyRepoProvider = Provider<ApiKeyRepository>(
  (ref) => ApiKeyRepository(ref.watch(deepgramSecureStorageProvider)),
);

/// Реактивный список Deepgram-ключей.
final deepgramApiKeysProvider = FutureProvider<List<ApiKeyView>>((ref) async {
  return ref.watch(deepgramApiKeyRepoProvider).listKeys();
});
