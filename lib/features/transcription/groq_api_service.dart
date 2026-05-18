import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../core/constants/app_constants.dart';
import '../../core/error/app_exception.dart';
import 'selected_audio_file.dart';
import 'transcription_result.dart';

// ────────────────────────────────────────────────────────────────────────────
// Парсинг retry-after заголовков (top-level для тестируемости)
// ────────────────────────────────────────────────────────────────────────────

/// Парсит заголовки HTTP 429-ответа и возвращает рекомендуемую задержку в секундах.
///
/// Порядок приоритетов (per D-06):
///   1. `retry-after` → целое число секунд
///   2. `x-ratelimit-reset-requests` и `x-ratelimit-reset-tokens` → мин из двух
///   3. Fallback 60 секунд
///
/// Безопасность T-04-02: значение ограничено сверху 3600 с (1 час),
/// чтобы Groq не мог заблокировать ключ на сутки через манипуляцию заголовком.
int parseRetryAfterFromHeaders(Map<String, String> headers) {
  // 1. retry-after (целые секунды)
  final retryAfter = headers['retry-after'];
  if (retryAfter != null) {
    final seconds = int.tryParse(retryAfter.trim());
    if (seconds != null && seconds > 0) {
      return min(seconds, 3600);
    }
  }

  // 2. x-ratelimit-reset-requests / x-ratelimit-reset-tokens (строки вида "2m59.56s")
  final resetReq = headers['x-ratelimit-reset-requests'];
  final resetTok = headers['x-ratelimit-reset-tokens'];
  int? secsReq = resetReq != null ? _parseDurationString(resetReq) : null;
  int? secsTok = resetTok != null ? _parseDurationString(resetTok) : null;

  if (secsReq != null || secsTok != null) {
    final result = [
      if (secsReq != null) secsReq,
      if (secsTok != null) secsTok,
    ].reduce(min);
    return min(result, 3600);
  }

  // 3. Fallback
  return 60;
}

/// Парсит строку вида "2h", "2m30s", "2m59.56s", "45s", "500ms" в целые секунды.
/// Возвращает 60 (fallback) если строка не распознана или сумма равна 0.
int _parseDurationString(String s) {
  var total = 0;

  // Часы: "2h"
  final hoursMatch = RegExp(r'(\d+)h').firstMatch(s);
  if (hoursMatch != null) {
    total += int.parse(hoursMatch.group(1)!) * 3600;
  }

  // Минуты: "2m" но не "ms"
  final minutesMatch = RegExp(r'(\d+)m(?!s)').firstMatch(s);
  if (minutesMatch != null) {
    total += int.parse(minutesMatch.group(1)!) * 60;
  }

  // Секунды (включая дробные): "59.56s"
  final secondsMatch = RegExp(r'([\d.]+)s').firstMatch(s);
  if (secondsMatch != null) {
    total += double.parse(secondsMatch.group(1)!).ceil();
  }

  return total > 0 ? total : 60;
}

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

  /// Транскрибация одного чанка из байт. Используется в Phase 2 чанкованием.
  /// Бросает [AuthException] / [NetworkException] / [RateLimitException] / [InternalException].
  Future<TranscriptionResult> transcribeChunk({
    required List<int> bytes,
    required String filename,
    required String apiKey,
  }) async {
    final client = _clientFactory();
    try {
      final uri = Uri.parse(AppConstants.groqApiUrl);
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $apiKey'
        ..fields['model'] = AppConstants.groqDefaultModel
        ..fields['response_format'] = AppConstants.groqResponseFormat
        // Для сборки чанков нужны segment-level таймкоды.
        // word-level здесь не нужен — _assembleResult использует только r.segments.
        // Groq ожидает повторяющееся поле timestamp_granularities[], передаём segment.
        ..fields['timestamp_granularities[]'] = 'segment'
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: filename,
            // Явно указываем audio/mpeg — fromBytes не выводит тип из расширения.
            contentType: MediaType('audio', 'mpeg'),
          ),
        );

      final streamed = await client.send(request).timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          client.close();
          throw const NetworkException('Превышено время ожидания ответа от Groq');
        },
      );
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        try {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          return TranscriptionResult.fromJson(json);
        } catch (_) {
          throw const InternalException('Не удалось разобрать ответ Groq');
        }
      }
      if (response.statusCode == 401) throw const AuthException(_authErrorMessage);
      if (response.statusCode == 429 || response.statusCode == 503) {
        // Парсим заголовки для определения времени ожидания (T-04-02: cap 3600 с)
        final retryAfterSeconds =
            parseRetryAfterFromHeaders(response.headers);
        throw RateLimitException(
          response.statusCode == 429
              ? 'Превышен лимит запросов Groq'
              : 'Сервис временно недоступен (503)',
          retryAfterSeconds: retryAfterSeconds,
        );
      }
      // Для всех остальных ошибок включаем тело ответа Groq для диагностики.
      throw NetworkException(
        'Groq ${response.statusCode}: ${response.body}',
      );
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

      final streamed = await client.send(request).timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          client.close();
          throw const NetworkException('Превышено время ожидания ответа от Groq');
        },
      );
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
      // 429 / 503: пробрасываем RateLimitException — TranscriptionController
      // должен сообщить пулу о блокировке через pool.reportRateLimited().
      // Идентично обработке в transcribeChunk().
      if (response.statusCode == 429 || response.statusCode == 503) {
        final retryAfterSeconds =
            parseRetryAfterFromHeaders(response.headers);
        throw RateLimitException(
          response.statusCode == 429
              ? 'Превышен лимит запросов Groq'
              : 'Сервис временно недоступен (503)',
          retryAfterSeconds: retryAfterSeconds,
        );
      }
      // 4xx (кроме 401/429), 5xx, 524
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
