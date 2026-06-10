import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/transcription/audio_chunking_service.dart';
import '../../features/transcription/deepgram_provider.dart';
import '../../features/transcription/file_picker_service.dart';
import '../../features/transcription/groq_api_service.dart';
import '../../features/transcription/key_pool.dart';
import '../../features/transcription/transcription_provider.dart';

/// Пул Groq-ключей. Переопределяется в ProviderScope через
/// groqKeyPoolProvider.overrideWithValue() при старте приложения.
final groqKeyPoolProvider = Provider<KeyPool>((ref) {
  throw UnimplementedError('groqKeyPoolProvider must be overridden in ProviderScope');
});

/// Пул Deepgram-ключей. Зеркало groqKeyPoolProvider для второго провайдера.
/// Переопределяется в ProviderScope через deepgramKeyPoolProvider.overrideWithValue().
final deepgramKeyPoolProvider = Provider<KeyPool>((ref) {
  throw UnimplementedError('deepgramKeyPoolProvider must be overridden in ProviderScope');
});

final audioChunkingServiceProvider = Provider<AudioChunkingService>(
  (ref) => AudioChunkingService(),
);

final filePickerServiceProvider = Provider<FilePickerService>(
  (ref) => const FilePickerService(),
);

final groqTranscriptionProviderProvider = Provider<TranscriptionProvider>(
  (_) => GroqProvider(),
);

final deepgramTranscriptionProviderProvider = Provider<TranscriptionProvider>(
  (_) => DeepgramProvider(),
);
