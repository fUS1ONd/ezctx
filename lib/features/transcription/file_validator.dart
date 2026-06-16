import '../../core/constants/app_constants.dart';

/// Результат валидации файла.
class FileValidationResult {
  final bool isOk;
  final String? errorMessage;

  const FileValidationResult._ok()
      : isOk = true,
        errorMessage = null;

  const FileValidationResult._error(this.errorMessage) : isOk = false;
}

/// Чистая функция валидации аудиофайла.
/// Проверяет whitelist расширений и минимальный размер (> 0 байт).
/// Ограничение максимального размера снято в Phase 2: chunking-пайплайн
/// обрабатывает файлы любого размера через нарезку на чанки ≤ 19 МБ.
class FileValidator {
  const FileValidator();

  FileValidationResult validate({
    required String path,
    required int sizeBytes,
  }) {
    final ext = FileValidator.extractExtension(path);
    if (!AppConstants.supportedAudioExtensions.contains(ext)) {
      return const FileValidationResult._error(
        'Формат файла не поддерживается. Выберите mp3, wav, m4a, ogg или flac.',
      );
    }
    // Минимальный размер: файл не должен быть пустым.
    if (sizeBytes <= 0) {
      return const FileValidationResult._error(
        'Файл пустой или недоступен. Выберите другой файл.',
      );
    }
    return const FileValidationResult._ok();
  }

  /// Извлекает расширение из пути в нижнем регистре.
  /// Берёт только последний сегмент после последней точки в имени файла.
  /// Вынесен как static, чтобы избежать дублирования в FilePickerService.
  static String extractExtension(String path) {
    final fileName = path.split('/').last;
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == fileName.length - 1) return '';
    return fileName.substring(dotIndex + 1).toLowerCase();
  }

  /// Срезает расширение, ТОЛЬКО если хвост после последней точки —
  /// известное медиа-расширение из whitelist. Иначе возвращает имя как есть.
  ///
  /// Нужно, чтобы точка в имени (например, дата «14.05 ОП») не принималась
  /// за разделитель расширения и не калечила имя при шеринге.
  static String stripKnownExtension(String name) {
    final ext = extractExtension(name);
    if (!AppConstants.supportedAudioExtensions.contains(ext)) return name;
    final dotIndex = name.lastIndexOf('.');
    return name.substring(0, dotIndex);
  }
}
