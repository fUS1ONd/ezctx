import 'package:flutter/foundation.dart';

import '../../core/error/app_exception.dart';
import 'groq_api_service.dart';
import 'groq_key_pool.dart';
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

/// Координатор транскрибации коротких файлов (< порога чанкования).
/// Использует [GroqKeyPool] для ротации ключей при rate-limit ошибках.
/// Зависимости инжектируются через конструктор (тестируемость).
class TranscriptionController extends ChangeNotifier {
  TranscriptionController({
    required GroqKeyPool pool,
    required GroqApiService apiService,
  })  : _pool = pool,
        _api = apiService;

  final GroqKeyPool _pool;
  final GroqApiService _api;

  bool _disposed = false;

  TranscriptionState _state = const TranscriptionIdle();
  TranscriptionState get state => _state;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _set(TranscriptionState s) {
    // Защита от вызова notifyListeners() после dispose() при отмене пользователем.
    if (_disposed) return;
    _state = s;
    notifyListeners();
  }

  /// Запустить транскрибацию. Файл передаётся снаружи (HomeScreen → ProcessingScreen).
  /// При HTTP 429 автоматически ротирует ключи через [GroqKeyPool].
  Future<void> start(SelectedAudioFile file) async {
    _set(const TranscriptionLoading());

    // Проверяем наличие ключей в пуле.
    if (_pool.allKeys.isEmpty) {
      _set(const TranscriptionMissingKey());
      return;
    }

    int attempt = 0;
    const maxAttempts = 10;

    while (attempt < maxAttempts) {
      String key;
      try {
        key = await _pool.acquireKey();
      } on AllKeysBlockedException {
        // Все ключи заблокированы и таймаут истёк.
        _set(const TranscriptionError(
          'Все ключи заблокированы. Подождите и повторите.',
          retryable: true,
        ));
        return;
      }

      try {
        final result = await _api.transcribe(file: file, apiKey: key);
        _set(TranscriptionSuccess(result));
        return;
      } on RateLimitException catch (e) {
        attempt++;
        // Сообщаем пулу о блокировке ключа на указанное время.
        _pool.reportRateLimited(key, e.retryAfterSeconds);
        // Продолжаем цикл — следующий acquireKey() выберет свободный ключ.
      } on AuthException catch (e) {
        // Неверный ключ — не ретраить.
        _set(TranscriptionError(e.message, retryable: false));
        return;
      } on NetworkException catch (e) {
        _set(TranscriptionError(e.message, retryable: true));
        return;
      } on InternalException catch (e) {
        _set(TranscriptionError(e.message, retryable: true));
        return;
      } catch (_) {
        _set(const TranscriptionError('Неизвестная ошибка', retryable: true));
        return;
      }
    }

    // Исчерпаны все попытки после RateLimitException.
    _set(const TranscriptionError(
      'Все ключи заблокированы. Подождите и повторите.',
      retryable: true,
    ));
  }
}
