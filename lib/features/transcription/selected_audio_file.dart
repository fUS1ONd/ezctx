import '../../core/utils/byte_format.dart';

/// Доменная модель выбранного аудиофайла.
/// Метаданные ffprobe (duration, codec) появятся в Phase 2.
class SelectedAudioFile {
  final String path;
  final String name;
  final int sizeBytes;
  final String extension; // нижний регистр без точки

  const SelectedAudioFile({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.extension,
  });

  /// Человекочитаемый размер (десятичные единицы, см. byte_format.dart).
  String get sizeFormatted => formatBytes(sizeBytes);
}
