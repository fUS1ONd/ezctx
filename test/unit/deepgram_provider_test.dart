import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:ezctx/core/error/app_exception.dart';
import 'package:ezctx/features/transcription/deepgram_provider.dart';
import 'package:ezctx/features/transcription/transcription_options.dart';
import 'package:ezctx/features/transcription/transcription_result.dart';

/// Создаёт http.Response с JSON-телом и правильной кодировкой (utf8).
/// Использует bytes, т.к. http.Response(body) по умолчанию latin1 — кириллица ломается.
http.Response _jsonResponse(Map<String, dynamic> data, int statusCode) {
  final bytes = utf8.encode(jsonEncode(data));
  return http.Response.bytes(
    bytes,
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

/// Создаёт DeepgramProvider с инжектированным MockClient для тестирования.
DeepgramProvider _providerWith(http.Client client) =>
    DeepgramProvider(clientFactory: () => client);

void main() {
  /// Тестовые константы.
  const fakeKey = 'dg_test_key_abcdef1234';
  const fakeBytes = [0x4F, 0x67, 0x67, 0x53]; // OGG magic bytes
  const fakeFilename = 'chunk_000.ogg';

  /// Загружает фикстуру из файла и декодирует как JSON.
  Map<String, dynamic> loadFixture(String name) {
    final file = File('test/fixtures/$name');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }

  group('DeepgramProvider — парсинг paragraphs', () {
    test('paragraphs→segments: количество сегментов и start первого', () async {
      final fixture = loadFixture('deepgram_nova3_response.json');

      final client = MockClient((_) async => _jsonResponse(fixture, 200));
      final result = await _providerWith(client).transcribeChunk(
        bytes: fakeBytes,
        filename: fakeFilename,
        apiKey: fakeKey,
      );

      // Фикстура содержит 2 предложения в 1 параграфе → 2 сегмента
      expect(result.segments.length, equals(2));
      // start первого сегмента из фикстуры ≈ 0.33
      expect(result.segments.first.start, closeTo(0.33, 0.01));
      expect(result, isA<TranscriptionResult>());
    });
  });

  group('DeepgramProvider — fallback парсинг', () {
    test('words→segments при пустых paragraphs', () async {
      // Фикстура с пустыми paragraphs, но заполненными words
      final data = {
        'results': {
          'channels': [
            {
              'detected_language': 'ru',
              'alternatives': [
                {
                  'transcript': 'Слово раз.',
                  'words': [
                    {'word': 'Слово', 'start': 0.10, 'end': 0.50},
                    {'word': 'раз.', 'start': 0.55, 'end': 0.90},
                  ],
                  'paragraphs': {
                    'transcript': '',
                    'paragraphs': <Map<String, dynamic>>[],
                  },
                }
              ],
            }
          ],
        },
      };

      final client = MockClient((_) async => _jsonResponse(data, 200));
      final result = await _providerWith(client).transcribeChunk(
        bytes: fakeBytes,
        filename: fakeFilename,
        apiKey: fakeKey,
      );

      // Fallback: 2 слова → 2 сегмента
      expect(result.segments.length, equals(2));
      expect(result.segments.first.text, equals('Слово'));
      expect(result.segments.first.start, closeTo(0.10, 0.01));
    });

    test('plain text при пустых paragraphs и пустых words', () async {
      final fixture = loadFixture('deepgram_nova3_response_empty.json');

      final client = MockClient((_) async => _jsonResponse(fixture, 200));
      final result = await _providerWith(client).transcribeChunk(
        bytes: fakeBytes,
        filename: fakeFilename,
        apiKey: fakeKey,
      );

      // Тишина: пустой transcript, 0 сегментов
      expect(result.text, equals(''));
      expect(result.segments, isEmpty);
    });
  });

  group('DeepgramProvider — URL параметры', () {
    test('detect_language=true при TranscriptionLanguage.auto', () async {
      Uri? capturedUri;
      final fixture = loadFixture('deepgram_nova3_response.json');

      final client = MockClient((req) async {
        capturedUri = req.url;
        return _jsonResponse(fixture, 200);
      });

      await _providerWith(client).transcribeChunk(
        bytes: fakeBytes,
        filename: fakeFilename,
        apiKey: fakeKey,
        options: const TranscriptionOptions(
          model: TranscriptionModel.nova3,
          language: TranscriptionLanguage.auto,
        ),
      );

      expect(capturedUri, isNotNull);
      final params = capturedUri!.queryParameters;
      // auto → detect_language, не language
      expect(params['detect_language'], equals('true'));
      expect(params.containsKey('language'), isFalse);
      // Обязательные параметры модели
      expect(params['model'], equals('nova-3'));
      expect(params['smart_format'], equals('true'));
      expect(params['paragraphs'], equals('true'));
    });

    test('language=ru при TranscriptionLanguage.ru', () async {
      Uri? capturedUri;
      final fixture = loadFixture('deepgram_nova3_response.json');

      final client = MockClient((req) async {
        capturedUri = req.url;
        return _jsonResponse(fixture, 200);
      });

      await _providerWith(client).transcribeChunk(
        bytes: fakeBytes,
        filename: fakeFilename,
        apiKey: fakeKey,
        options: const TranscriptionOptions(
          model: TranscriptionModel.nova3,
          language: TranscriptionLanguage.ru,
        ),
      );

      expect(capturedUri, isNotNull);
      final params = capturedUri!.queryParameters;
      // Явный язык → передаётся как language=ru
      expect(params['language'], equals('ru'));
      expect(params.containsKey('detect_language'), isFalse);
    });
  });

  group('DeepgramProvider — заголовки запроса', () {
    test('Authorization: Token <key> и Content-Type: audio/ogg', () async {
      Map<String, String>? capturedHeaders;
      final fixture = loadFixture('deepgram_nova3_response.json');

      final client = MockClient((req) async {
        capturedHeaders = req.headers;
        return _jsonResponse(fixture, 200);
      });

      await _providerWith(client).transcribeChunk(
        bytes: fakeBytes,
        filename: fakeFilename,
        apiKey: fakeKey,
      );

      expect(capturedHeaders, isNotNull);
      // Deepgram использует Token, не Bearer
      expect(capturedHeaders!['authorization'], equals('Token $fakeKey'));
      // Raw bytes POST с правильным MIME-типом
      expect(
        capturedHeaders!['content-type'],
        startsWith('audio/ogg'),
      );
    });
  });

  group('DeepgramProvider — маппинг HTTP-ошибок', () {
    test('401 → AuthException', () async {
      final client = MockClient(
        (_) async => http.Response('Unauthorized', 401),
      );

      await expectLater(
        () => _providerWith(client).transcribeChunk(
          bytes: fakeBytes,
          filename: fakeFilename,
          apiKey: fakeKey,
        ),
        throwsA(isA<AuthException>()),
      );
    });

    test('402 → KeyExhaustedException', () async {
      final client = MockClient(
        (_) async => http.Response('Payment Required', 402),
      );

      await expectLater(
        () => _providerWith(client).transcribeChunk(
          bytes: fakeBytes,
          filename: fakeFilename,
          apiKey: fakeKey,
        ),
        throwsA(isA<KeyExhaustedException>()),
      );
    });

    test('429 → RateLimitException', () async {
      final client = MockClient(
        (_) async => http.Response('Too Many Requests', 429),
      );

      await expectLater(
        () => _providerWith(client).transcribeChunk(
          bytes: fakeBytes,
          filename: fakeFilename,
          apiKey: fakeKey,
        ),
        throwsA(isA<RateLimitException>()),
      );
    });

    test('504 → NetworkException', () async {
      final client = MockClient(
        (_) async => http.Response('Gateway Timeout', 504),
      );

      await expectLater(
        () => _providerWith(client).transcribeChunk(
          bytes: fakeBytes,
          filename: fakeFilename,
          apiKey: fakeKey,
        ),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('DeepgramProvider — конкурентность', () {
    test('concurrencyFor(0) == 0, concurrencyFor(1) == 5, concurrencyFor(3) == 5',
        () {
      final provider = DeepgramProvider();
      // При нулевом числе ключей — параллелизм отключён
      expect(provider.concurrencyFor(0), equals(0));
      // При наличии ключей — максимум 5 параллельных запросов
      expect(provider.concurrencyFor(1), equals(5));
      expect(provider.concurrencyFor(3), equals(5));
    });
  });
}
