import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:ezctx/core/error/app_exception.dart';
import 'package:ezctx/features/transcription/groq_api_service.dart';
import 'package:ezctx/features/transcription/transcription_result.dart';

/// http.Response(body, statusCode) кодирует тело в latin1 по умолчанию.
/// Кириллица в latin1 вызывает ArgumentError — используем bytes с явным charset.
http.Response _jsonResponse(Map<String, dynamic> data, int statusCode) {
  final bytes = utf8.encode(jsonEncode(data));
  return http.Response.bytes(
    bytes,
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

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

void main() {
  const _fakeKey = 'gsk_testkey';
  const _fakeBytes = [0x49, 0x44, 0x33]; // mp3 header magic bytes
  const _fakeFilename = 'chunk_000.mp3';

  GroqProvider _serviceWith(http.Client client) =>
      GroqProvider(clientFactory: () => client);

  group('GroqProvider.transcribeChunk — content type', () {
    test('запрос содержит Content-Type: audio/mpeg для mp3-чанка', () async {
      String? capturedContentType;

      final client = _MultipartCapturingClient((request) async {
        final filePart = request.files.firstWhere((f) => f.field == 'file');
        capturedContentType = filePart.contentType.toString();
        return _jsonResponse({
          'text': 'Hello',
          'language': 'ru',
          'duration': 5.0,
          'segments': <dynamic>[],
        }, 200);
      });

      await _serviceWith(client).transcribeChunk(
        bytes: _fakeBytes,
        filename: _fakeFilename,
        apiKey: _fakeKey,
      );

      expect(capturedContentType, equals('audio/mpeg'));
    });

    test('запрос содержит поле timestamp_granularities[]=segment', () async {
      String? capturedGranularity;

      final client = _MultipartCapturingClient((request) async {
        capturedGranularity = request.fields['timestamp_granularities[]'];
        return _jsonResponse({
          'text': 'ok',
          'language': 'ru',
          'duration': 1.0,
          'segments': <dynamic>[],
        }, 200);
      });

      await _serviceWith(client).transcribeChunk(
        bytes: _fakeBytes,
        filename: _fakeFilename,
        apiKey: _fakeKey,
      );

      expect(capturedGranularity, equals('segment'));
    });
  });

  group('GroqProvider.transcribeChunk — ответы', () {
    test('200 → TranscriptionResult с сегментами', () async {
      final client = MockClient((_) async => _jsonResponse({
            'text': '[00:00:00] Hello world',
            'language': 'ru',
            'duration': 5.0,
            'segments': [
              {'start': 0.0, 'end': 2.0, 'text': 'Hello world'},
            ],
          }, 200));

      final result = await _serviceWith(client).transcribeChunk(
        bytes: _fakeBytes,
        filename: _fakeFilename,
        apiKey: _fakeKey,
      );

      expect(result, isA<TranscriptionResult>());
      expect(result.text, contains('Hello world'));
      expect(result.segments.length, equals(1));
      expect(result.segments.first.start, equals(0.0));
    });

    test('401 → AuthException', () async {
      final client = MockClient(
        (_) async => http.Response('Unauthorized', 401),
      );

      await expectLater(
        () => _serviceWith(client).transcribeChunk(
          bytes: _fakeBytes,
          filename: _fakeFilename,
          apiKey: _fakeKey,
        ),
        throwsA(isA<AuthException>()),
      );
    });

    test('429 → RateLimitException', () async {
      final client = MockClient(
        (_) async => http.Response('Rate limited', 429),
      );

      await expectLater(
        () => _serviceWith(client).transcribeChunk(
          bytes: _fakeBytes,
          filename: _fakeFilename,
          apiKey: _fakeKey,
        ),
        throwsA(isA<RateLimitException>()),
      );
    });

    test('400 → NetworkException с телом ответа Groq (для диагностики)',
        () async {
      const groqErrorBody =
          '{"error":{"message":"Invalid file format","type":"invalid_request_error"}}';
      final client = MockClient(
        (_) async => http.Response(groqErrorBody, 400),
      );

      await expectLater(
        () => _serviceWith(client).transcribeChunk(
          bytes: _fakeBytes,
          filename: _fakeFilename,
          apiKey: _fakeKey,
        ),
        throwsA(
          isA<NetworkException>().having(
            (e) => e.message,
            'message',
            allOf(contains('400'), contains('Invalid file format')),
          ),
        ),
      );
    });

    test('500 → NetworkException с кодом и телом', () async {
      final client = MockClient(
        (_) async => http.Response('Internal Server Error', 500),
      );

      await expectLater(
        () => _serviceWith(client).transcribeChunk(
          bytes: _fakeBytes,
          filename: _fakeFilename,
          apiKey: _fakeKey,
        ),
        throwsA(
          isA<NetworkException>().having(
            (e) => e.message,
            'message',
            contains('500'),
          ),
        ),
      );
    });
  });
}
