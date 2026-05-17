import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';
import '../../core/error/app_exception.dart';
import 'selected_audio_file.dart';
import 'transcription_result.dart';

/// HTTP-клиент для Groq Whisper. Phase 1: single-shot (один файл, один запрос).
/// Чанкование и параллельность — Phase 2.
class GroqApiService {
  /// [clientFactory] инжектируется для тестирования через MockClient.
  /// В production вызов без аргумента создаёт стандартный http.Client.
  GroqApiService({http.Client Function()? clientFactory})
      : _clientFactory = clientFactory ?? (() => http.Client());

  final http.Client Function() _clientFactory;

  static const _authErrorMessage =
      'Ключ не подошёл. Проверьте его в console.groq.com → API Keys.';
  static const _networkErrorMessage =
      'Не удалось подключиться к Groq. Проверьте интернет и попробуйте снова.';

  /// Single-shot транскрибация. Бросает [AuthException]/[NetworkException]/[InternalException].
  Future<TranscriptionResult> transcribe({
    required SelectedAudioFile file,
    required String apiKey,
  }) async {
    final client = _clientFactory();
    try {
      final uri = Uri.parse(AppConstants.groqApiUrl);
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $apiKey'
        ..fields['model'] = AppConstants.groqDefaultModel
        ..fields['response_format'] = AppConstants.groqResponseFormat
        // Pitfall 3: имя поля с '[]' обязательно (Groq API соглашение для массивов).
        ..fields['timestamp_granularities[]'] =
            AppConstants.groqTimestampGranularity
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamed = await client.send(request);
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        try {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          return TranscriptionResult.fromJson(json);
        } catch (_) {
          throw const InternalException('Не удалось разобрать ответ Groq');
        }
      }
      if (response.statusCode == 401) {
        throw const AuthException(_authErrorMessage);
      }
      // 4xx (кроме 401), 5xx, 524
      throw const NetworkException(_networkErrorMessage);
    } on SocketException {
      throw const NetworkException(_networkErrorMessage);
    } on TimeoutException {
      throw const NetworkException(_networkErrorMessage);
    } on AppException {
      rethrow;
    } catch (_) {
      throw const NetworkException(_networkErrorMessage);
    } finally {
      client.close();
    }
  }
}
