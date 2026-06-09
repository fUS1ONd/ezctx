import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:ezctx/features/transcription/groq_api_service.dart';

/// Кастомный BaseClient — перехватывает MultipartRequest ДО финализации.
/// MockClient финализирует запрос перед вызовом хендлера, теряя .files/.fields.
class _MultipartCapturingClient extends http.BaseClient {
  final Future<http.Response> Function(http.MultipartRequest) _handler;

  _MultipartCapturingClient(this._handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _handler(request as http.MultipartRequest);
    return http.StreamedResponse(
      Stream<List<int>>.fromIterable([response.bodyBytes]),
      response.statusCode,
      headers: response.headers,
      reasonPhrase: response.reasonPhrase,
    );
  }
}

/// Вспомогательная функция: строит JSON-ответ с явной кодировкой UTF-8.
http.Response _jsonResponse(Map<String, dynamic> data, int statusCode) {
  final bytes = utf8.encode(jsonEncode(data));
  return http.Response.bytes(
    bytes,
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  // Wave 0 — NORM-03: MIME-инвариант audio/ogg для GroqApiService (Phase 08)
  group('GroqApiService — MIME-инвариант (NORM-03)', () {
    test('GroqApiService.transcribeChunk отправляет Content-Type audio/ogg',
        () async {
      String? capturedContentType;

      // Клиент перехватывает multipart-запрос и читает Content-Type file-части.
      final client = _MultipartCapturingClient((request) async {
        final filePart = request.files.firstWhere((f) => f.field == 'file');
        capturedContentType = filePart.contentType.toString();
        // Возвращаем валидный verbose_json — минимальный body с text и segments.
        return _jsonResponse({
          'text': 'тест',
          'language': 'ru',
          'duration': 1.0,
          'segments': <dynamic>[],
        }, 200);
      });

      final service = GroqProvider(clientFactory: () => client);

      await service.transcribeChunk(
        bytes: [0x4f, 0x67, 0x67, 0x53], // OGG capture pattern magic bytes
        filename: 'chunk_000.ogg',
        apiKey: 'gsk_testkey',
      );

      // NORM-03: провайдер ДОЛЖЕН отправлять audio/ogg, а не audio/mpeg.
      expect(capturedContentType, equals('audio/ogg'));
    });
  });
}
