import 'audio_metadata.dart';
import 'selected_audio_file.dart';
import 'transcription_options.dart';

/// Аргументы маршрута /processing.
class ProcessingArgs {
  final SelectedAudioFile file;

  /// Метаданные из ffprobe. null — если ffprobe не вернул результат.
  final AudioMetadata? metadata;

  /// Настройки транскрибации: модель и язык.
  final TranscriptionOptions options;

  const ProcessingArgs({
    required this.file,
    this.metadata,
    this.options = const TranscriptionOptions.defaults(),
  });
}
