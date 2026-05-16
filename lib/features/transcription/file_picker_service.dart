import 'package:file_picker/file_picker.dart';

import '../../core/constants/app_constants.dart';
import '../../core/error/app_exception.dart';
import 'file_validator.dart';
import 'selected_audio_file.dart';

/// Результат попытки выбора файла.
sealed class FilePickResult {
  const FilePickResult();
}

/// Пользователь выбрал валидный файл.
class FilePickPicked extends FilePickResult {
  final SelectedAudioFile file;
  const FilePickPicked(this.file);
}

/// Пользователь закрыл диалог без выбора.
class FilePickCancelled extends FilePickResult {
  const FilePickCancelled();
}

/// Обёртка над системным file_picker.
/// Открывает диалог → валидирует через FileValidator → возвращает [FilePickResult]
/// или бросает [ValidationException] при невалидном файле.
///
/// Примечание: FilePickerService тестируется на устройстве, не в unit-suite
/// (FilePicker.platform — статический singleton, mock требует нестандартных инструментов).
class FilePickerService {
  const FilePickerService();

  Future<FilePickResult> pickAudioFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: AppConstants.supportedAudioExtensions.toList(),
      allowMultiple: false,
      withData: false,
      withReadStream: false,
    );

    if (result == null || result.files.isEmpty) {
      return const FilePickCancelled();
    }

    final platformFile = result.files.first;
    final path = platformFile.path;
    if (path == null) {
      throw const ValidationException('Не удалось получить путь к файлу');
    }

    final validation = const FileValidator().validate(
      path: path,
      sizeBytes: platformFile.size,
    );

    if (!validation.isOk) {
      throw ValidationException(validation.errorMessage!);
    }

    final ext = _extractExtension(path);

    return FilePickPicked(SelectedAudioFile(
      path: path,
      name: platformFile.name,
      sizeBytes: platformFile.size,
      extension: ext,
    ));
  }

  String _extractExtension(String path) {
    final fileName = path.split('/').last;
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == fileName.length - 1) return '';
    return fileName.substring(dotIndex + 1).toLowerCase();
  }
}
