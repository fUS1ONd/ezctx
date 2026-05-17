import 'audio_metadata.dart';
import 'selected_audio_file.dart';

/// Аргументы маршрута /processing.
///
/// Объединяет выбранный файл и опциональные метаданные (из ffprobe).
class ProcessingArgs {
  final SelectedAudioFile file;

  /// Метаданные из ffprobe. null — если ffprobe не вернул результат.
  final AudioMetadata? metadata;

  const ProcessingArgs({required this.file, this.metadata});
}
