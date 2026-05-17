import 'package:flutter/foundation.dart';

import '../../core/error/app_exception.dart';
import '../settings/api_key_repository.dart';
import 'groq_api_service.dart';
import 'selected_audio_file.dart';
import 'transcription_result.dart';

sealed class TranscriptionState {
  const TranscriptionState();
}

class TranscriptionIdle extends TranscriptionState {
  const TranscriptionIdle();
}

class TranscriptionLoading extends TranscriptionState {
  const TranscriptionLoading();
}

class TranscriptionSuccess extends TranscriptionState {
  final TranscriptionResult result;
  const TranscriptionSuccess(this.result);
}

class TranscriptionError extends TranscriptionState {
  final String message;
  final bool retryable;
  const TranscriptionError(this.message, {required this.retryable});
}

class TranscriptionMissingKey extends TranscriptionState {
  const TranscriptionMissingKey();
}

/// Координатор транскрибации: ключ → HTTP-сервис → state для UI.
/// Зависимости инжектируются через конструктор (тестируемость).
class TranscriptionController extends ChangeNotifier {
  TranscriptionController({
    required ApiKeyRepository keyRepository,
    required GroqApiService apiService,
  })  : _keys = keyRepository,
        _api = apiService;

  final ApiKeyRepository _keys;
  final GroqApiService _api;

  TranscriptionState _state = const TranscriptionIdle();
  TranscriptionState get state => _state;

  void _set(TranscriptionState s) {
    _state = s;
    notifyListeners();
  }

  /// Запустить транскрибацию. Файл передаётся снаружи (HomeScreen → ProcessingScreen).
  Future<void> start(SelectedAudioFile file) async {
    _set(const TranscriptionLoading());

    final keys = await _keys.listKeys();
    if (keys.isEmpty) {
      _set(const TranscriptionMissingKey());
      return;
    }

    try {
      final result = await _api.transcribe(file: file, apiKey: keys.first.raw);
      _set(TranscriptionSuccess(result));
    } on AuthException catch (e) {
      _set(TranscriptionError(e.message, retryable: false));
    } on NetworkException catch (e) {
      _set(TranscriptionError(e.message, retryable: true));
    } on InternalException catch (e) {
      _set(TranscriptionError(e.message, retryable: true));
    } catch (_) {
      _set(TranscriptionError('Неизвестная ошибка', retryable: true));
    }
  }
}
