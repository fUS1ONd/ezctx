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

  /// Файл требует чанкования если его размер ≥ 19 МБ.
  ///
  /// Groq API отклоняет одиночные файлы > 19.5 МБ независимо от длительности,
  /// поэтому проверка идёт по байтам, а не по времени. ffmpeg перекодирует
  /// файл в 128kbps — результирующий чанк меньше оригинала.
  bool get isChunked => file.sizeBytes >= 19 * 1024 * 1024;
}
