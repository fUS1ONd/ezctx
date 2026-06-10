import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';
import '../../core/error/app_exception.dart';
import 'transcription_options.dart';
import 'transcription_provider.dart';
import 'transcription_result.dart';

/// Реализация [TranscriptionProvider] для Deepgram nova-3.
/// Отправляет raw-bytes POST к Deepgram REST API и парсит ответ
/// с paragraphs/sentences в список [TranscriptionSegment].
class DeepgramProvider implements TranscriptionProvider {
  /// [clientFactory] инжектируется для тестирования через MockClient.
  /// В production вызов без аргумента создаёт стандартный http.Client.
  DeepgramProvider({http.Client Function()? clientFactory})
      : _clientFactory = clientFactory ?? (() => http.Client());

  final http.Client Function() _clientFactory;

  /// Сообщение об ошибке аутентификации (401).
  static const _authErrorMessage =
      'Ключ не подошёл. Проверьте его в console.deepgram.com → API Keys.';

  /// Сообщение о сетевой ошибке (SocketException / TimeoutException).
  static const _networkErrorMessage =
      'Не удалось подключиться к Deepgram. Проверьте интернет и попробуйте снова.';

  /// Транскрибация одного чанка из байт через Deepgram nova-3.
  /// Бросает [AuthException] / [KeyExhaustedException] / [RateLimitException]
  /// / [NetworkException] / [InternalException].
  @override
  Future<TranscriptionResult> transcribeChunk({
    required List<int> bytes,
    required String filename,
    required String apiKey,
    TranscriptionOptions options = const TranscriptionOptions.defaults(),
  }) async {
    final client = _clientFactory();
    try {
      // Строим URI с query-параметрами; ключ ТОЛЬКО в заголовке (T-10-01).
      final uri = Uri.parse(AppConstants.deepgramApiUrl).replace(
        queryParameters: {
          'model': options.model.apiValue, // 'nova-3'
          'smart_format': 'true',
          'paragraphs': 'true',
          // При auto — просим определить язык автоматически; иначе — явный isoCode.
          if (options.language == TranscriptionLanguage.auto)
            'detect_language': 'true'
          else
            'language': options.language.isoCode,
        },
      );

      // Raw-bytes POST — не multipart (в отличие от Groq).
      final response = await client.post(
        uri,
        headers: {
          // Deepgram требует Token, не Bearer (T-10-01).
          'Authorization': 'Token $apiKey',
          // Нормализованный формат: opus/ogg из фазы 08.
          'Content-Type': 'audio/ogg',
        },
        body: Uint8List.fromList(bytes),
      ).timeout(const Duration(minutes: 5));

      if (response.statusCode == 200) {
        try {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          return _parseResponse(json, options);
        } catch (_) {
          throw const InternalException('Не удалось разобрать ответ Deepgram');
        }
      }

      // Маппинг HTTP-кодов Deepgram → нормализованные исключения.
      if (response.statusCode == 401) {
        throw const AuthException(_authErrorMessage);
      }
      if (response.statusCode == 402) {
        // Кредиты ключа исчерпаны — ключ выводится из ротации навсегда.
        throw const KeyExhaustedException();
      }
      if (response.statusCode == 429) {
        // Deepgram не документирует нестандартные retry-headers;
        // читаем стандартный retry-after если присутствует, иначе fallback 60 с.
        final retryAfter =
            int.tryParse(response.headers['retry-after']?.trim() ?? '');
        throw RateLimitException(
          'Превышен лимит запросов Deepgram',
          retryAfterSeconds:
              (retryAfter != null && retryAfter > 0) ? retryAfter : 60,
        );
      }

      // 400/403 — клиентские ошибки (неверный запрос / нет доступа).
      if (response.statusCode == 400 || response.statusCode == 403) {
        throw NetworkException('Deepgram error ${response.statusCode}');
      }

      // 504 / 5xx — сетевые/серверные ошибки; тело не включаем,
      // чтобы потенциальный API-ключ/секрет не утёк в текст исключения (T-10-02).
      throw NetworkException('Deepgram error ${response.statusCode}');
    } on SocketException {
      throw const NetworkException(_networkErrorMessage);
    } on TimeoutException {
      throw const NetworkException(_networkErrorMessage);
    } on AppException {
      rethrow;
    } catch (e) {
      if (e is TypeError) {
        throw InternalException('Неожиданная схема ответа Deepgram: $e');
      }
      throw const NetworkException(_networkErrorMessage);
    } finally {
      client.close();
    }
  }

  /// Парсит JSON-ответ Deepgram в [TranscriptionResult].
  /// Цепочка fallback: paragraphs.sentences → words → плоский transcript.
  TranscriptionResult _parseResponse(
    Map<String, dynamic> json,
    TranscriptionOptions options,
  ) {
    // Защита от пустого или неожиданного ответа (Open Question A2).
    final channels = json['results']?['channels'] as List?;
    if (channels == null || channels.isEmpty) {
      return const TranscriptionResult.empty();
    }

    final channel = channels.first as Map<String, dynamic>;
    final alternatives = channel['alternatives'] as List?;
    if (alternatives == null || alternatives.isEmpty) {
      return const TranscriptionResult.empty();
    }

    final alt = alternatives.first as Map<String, dynamic>;
    final transcript = alt['transcript'] as String? ?? '';

    // detected_language находится на уровне channel, не alternative (Pitfall 3).
    // Fallback на явный язык из настроек если Deepgram не определил (Open Question A1).
    final detectedLanguage =
        channel['detected_language'] as String? ?? options.language.isoCode;

    // Попытка 1: paragraphs → sentences (предпочтительный режим).
    // Pitfall 2: alt['paragraphs'] — это Map, внутри ['paragraphs'] — List.
    final paragraphsObj = alt['paragraphs'] as Map<String, dynamic>?;
    final paragraphsList = paragraphsObj?['paragraphs'] as List?;

    if (paragraphsList != null && paragraphsList.isNotEmpty) {
      final segments = <TranscriptionSegment>[];
      for (final para in paragraphsList) {
        final sentences =
            (para as Map<String, dynamic>)['sentences'] as List? ?? [];
        for (final s in sentences) {
          final sm = s as Map<String, dynamic>;
          segments.add(TranscriptionSegment(
            // start/end — 0-based от начала чанка, НЕ прибавлять offset (Pitfall 5).
            start: ((sm['start'] as num?)?.toDouble()) ?? 0.0,
            end: ((sm['end'] as num?)?.toDouble()) ?? 0.0,
            text: (sm['text'] as String?) ?? '',
          ));
        }
      }
      // duration = end последнего параграфа (Pitfall 4: Deepgram не возвращает поле duration).
      final lastPara = paragraphsList.last as Map<String, dynamic>;
      final duration = (lastPara['end'] as num?)?.toDouble() ?? 0.0;
      return TranscriptionResult(
        text: transcript,
        plainText: transcript,
        language: detectedLanguage,
        duration: duration,
        words: const [],
        segments: segments,
      );
    }

    // Попытка 2: words → segments (fallback при отсутствии paragraphs).
    final wordsList = alt['words'] as List?;
    if (wordsList != null && wordsList.isNotEmpty) {
      final segments = wordsList.map((w) {
        final wm = w as Map<String, dynamic>;
        return TranscriptionSegment(
          start: ((wm['start'] as num?)?.toDouble()) ?? 0.0,
          end: ((wm['end'] as num?)?.toDouble()) ?? 0.0,
          text: (wm['word'] as String?) ?? '',
        );
      }).toList();
      final lastWord = wordsList.last as Map<String, dynamic>;
      final duration = (lastWord['end'] as num?)?.toDouble() ?? 0.0;
      return TranscriptionResult(
        text: transcript,
        plainText: transcript,
        language: detectedLanguage,
        duration: duration,
        words: const [],
        segments: segments,
      );
    }

    // Попытка 3: только плоский transcript (тишина или нет разметки).
    return TranscriptionResult(
      text: transcript,
      plainText: transcript,
      language: detectedLanguage,
      duration: 0.0,
      words: const [],
      segments: const [],
    );
  }

  /// Число параллельных запросов: 5 при наличии ключей, 0 при отсутствии.
  @override
  int concurrencyFor(int aliveKeyCount) => aliveKeyCount > 0 ? 5 : 0;

  /// Идентификатор провайдера — Deepgram.
  @override
  TranscriptionProviderId get id => TranscriptionProviderId.deepgram;
}
