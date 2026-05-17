/// Value object, представляющий нормализованный аудиофайл во временной директории.
class NormalizedAudioFile {
  /// Путь к tmp mp3-файлу после нормализации через ffmpeg.
  final String path;

  /// Длительность нормализованного файла в секундах.
  final double durationSeconds;

  const NormalizedAudioFile({
    required this.path,
    required this.durationSeconds,
  });
}
