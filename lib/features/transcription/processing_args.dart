import 'audio_metadata.dart';
import 'selected_audio_file.dart';

/// Аргументы маршрута /processing.
///
/// Объединяет выбранный файл и опциональные метаданные (из ffprobe).
/// Для файлов < 19 МБ используется [TranscriptionController] (Phase 1 путь).
/// Для файлов ≥ 19 МБ — [ChunkedTranscriptionController].
class ProcessingArgs {
  final SelectedAudioFile file;

  /// Метаданные из ffprobe. null — если ffprobe не вернул результат
  /// (короткий файл или ffprobe завершился с ошибкой).
  final AudioMetadata? metadata;

  const ProcessingArgs({required this.file, this.metadata});

  /// Файл считается «длинным» и требует чанкования, если размер ≥ 19 МБ.
  bool get isChunked => file.sizeBytes >= 19 * 1024 * 1024;
}
