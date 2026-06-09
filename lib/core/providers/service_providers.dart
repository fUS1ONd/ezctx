import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/transcription/audio_chunking_service.dart';
import '../../features/transcription/file_picker_service.dart';
import '../../features/transcription/groq_api_service.dart';
import '../../features/transcription/key_pool.dart';
import '../../features/transcription/transcription_provider.dart';

/// Переопределяется в ProviderScope через groqKeyPoolProvider.overrideWithValue().
/// Имя провайдера groqKeyPoolProvider сохранено намеренно — переименование в
/// keyPoolProvider запланировано на фазу 10 (DI-проводка Deepgram).
final groqKeyPoolProvider = Provider<KeyPool>((ref) {
  throw UnimplementedError('groqKeyPoolProvider must be overridden in ProviderScope');
});

/// Провайдеро-независимая точка DI: контроллер и UI зависят от интерфейса
/// [TranscriptionProvider], не от конкретной реализации. Сейчас единственная
/// реализация — [GroqProvider] (Phase 10 добавит DeepgramProvider).
final transcriptionProviderProvider = Provider<TranscriptionProvider>(
  (ref) => GroqProvider(),
);

final audioChunkingServiceProvider = Provider<AudioChunkingService>(
  (ref) => AudioChunkingService(),
);

final filePickerServiceProvider = Provider<FilePickerService>(
  (ref) => const FilePickerService(),
);
