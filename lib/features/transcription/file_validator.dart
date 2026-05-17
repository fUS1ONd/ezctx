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
/// Проверяет whitelist расширений и размер. Нет I/O, нет state.
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
    if (sizeBytes > AppConstants.maxFileSizeBytes) {
      return const FileValidationResult._error(
        'Файл слишком большой (максимум 19 МБ). Поддержка больших файлов — в следующем обновлении.',
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
}
