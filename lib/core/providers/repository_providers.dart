import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/api_key_repository.dart';
import '../../features/settings/transcription_options_repository.dart';
import 'storage_providers.dart';

final apiKeyRepoProvider = Provider<ApiKeyRepository>(
  (ref) => ApiKeyRepository(ref.watch(secureStorageProvider)),
);

final transcriptionOptionsRepoProvider = Provider<TranscriptionOptionsRepository>(
  (ref) => TranscriptionOptionsRepository(),
);

/// Реактивный список ключей для баннера на HomeScreen.
final apiKeysProvider = FutureProvider<List<ApiKeyView>>((ref) async {
  return ref.watch(apiKeyRepoProvider).listKeys();
});
