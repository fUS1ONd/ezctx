import 'selected_audio_file.dart';
import 'transcription_options.dart';
import 'transcription_result.dart';

/// Аргументы для маршрута /result.
/// Передаются через Navigator.pushReplacementNamed(..., arguments: ResultArgs(...)).
class ResultArgs {
  final SelectedAudioFile file;
  final TranscriptionResult result;

  /// Опции транскрибации, использованные при расшифровке.
  /// Нужны для автозаписи в историю: из них берётся провайдер (D-08).
  /// Дефолт сохраняет обратную совместимость существующих call-site'ов и тестов.
  final TranscriptionOptions options;

  const ResultArgs({
    required this.file,
    required this.result,
    this.options = const TranscriptionOptions.defaults(),
  });
}
