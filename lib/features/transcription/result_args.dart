import 'selected_audio_file.dart';
import 'transcription_result.dart';

/// Аргументы для маршрута /result.
/// Передаются через Navigator.pushReplacementNamed(..., arguments: ResultArgs(...)).
class ResultArgs {
  final SelectedAudioFile file;
  final TranscriptionResult result;

  const ResultArgs({required this.file, required this.result});
}
