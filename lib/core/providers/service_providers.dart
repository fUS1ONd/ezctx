import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/transcription/audio_chunking_service.dart';
import '../../features/transcription/groq_api_service.dart';
import '../../features/transcription/groq_key_pool.dart';

/// Переопределяется в ProviderScope через groqKeyPoolProvider.overrideWithValue().
final groqKeyPoolProvider = Provider<GroqKeyPool>((ref) {
  throw UnimplementedError('groqKeyPoolProvider must be overridden in ProviderScope');
});

final groqApiServiceProvider = Provider<GroqApiService>(
  (ref) => GroqApiService(),
);

final audioChunkingServiceProvider = Provider<AudioChunkingService>(
  (ref) => AudioChunkingService(),
);
