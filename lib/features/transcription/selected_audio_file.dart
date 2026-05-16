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

  /// Размер в МБ с 1 знаком после запятой, для UI.
  String get sizeFormatted {
    final mb = sizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} МБ';
  }
}
