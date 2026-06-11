import 'dart:convert';
import 'dart:io';

import 'package:ezctx/core/error/app_exception.dart';
import 'package:ezctx/features/transcription/groq_api_service.dart';
import 'package:ezctx/features/transcription/selected_audio_file.dart';
import 'package:ezctx/features/transcription/transcription_result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late SelectedAudioFile testFile;

  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('ezctx_test');
    final f = File('${dir.path}/test.mp3');
    await f.writeAsBytes([]);
    testFile = SelectedAudioFile(
      path: f.path,
      name: 'test.mp3',
      sizeBytes: 0,
      extension: 'mp3',
    );
  });

  group('GroqProvider', () {
    test('успешный 200 → TranscriptionResult с text и words', () async {
      final service = GroqProvider(
        clientFactory: () => MockClient((req) async {
          expect(req.method, 'POST');
          expect(req.url.toString(), contains('api.groq.com'));
          expect(req.headers['authorization'], 'Bearer test-key');
          expect(req.body, contains('whisper-large-v3'));
          expect(req.body, contains('verbose_json'));
          expect(req.body, contains('timestamp_granularities[]'));
          // Bug 1: single-shot должен запрашивать segment-level таймкоды,
          // иначе Groq не возвращает segments[] и переключатель «С метками /
          // Без меток» на ResultScreen теряет разницу.
          final granularityBlock = RegExp(
            r'name="timestamp_granularities\[\]"\r?\n\r?\n([a-z]+)',
          ).firstMatch(req.body);
          expect(granularityBlock?.group(1), 'segment');
          return http.Response(
            jsonEncode({
              'text': 'Привет мир',
              'language': 'russian',
              'duration': 5.2,
              'words': [
                {'word': 'Привет', 'start': 0.0, 'end': 0.5},
                {'word': 'мир', 'start': 0.5, 'end': 0.9},
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final result = await service.transcribe(file: testFile, apiKey: 'test-key');
      expect(result.text, 'Привет мир');
      expect(result.language, 'russian');
      expect(result.words.length, 2);
      expect(result.words.first.word, 'Привет');
    });

    test('HTTP 401 → AuthException', () async {
      final service = GroqProvider(
        clientFactory: () => MockClient((_) async => http.Response('', 401)),
      );
      expect(
        () => service.transcribe(file: testFile, apiKey: 'bad-key'),
        throwsA(isA<AuthException>()),
      );
    });

    test('HTTP 500 → NetworkException', () async {
      final service = GroqProvider(
        clientFactory: () => MockClient((_) async => http.Response('', 500)),
      );
      expect(
        () => service.transcribe(file: testFile, apiKey: 'k'),
        throwsA(isA<NetworkException>()),
      );
    });

    test('HTTP 524 (Cloudflare timeout) → NetworkException', () async {
      final service = GroqProvider(
        clientFactory: () => MockClient((_) async => http.Response('', 524)),
      );
      expect(
        () => service.transcribe(file: testFile, apiKey: 'k'),
        throwsA(isA<NetworkException>()),
      );
    });

    test('невалидный JSON в 200 → InternalException', () async {
      final service = GroqProvider(
        clientFactory: () =>
            MockClient((_) async => http.Response('not json', 200)),
      );
      expect(
        () => service.transcribe(file: testFile, apiKey: 'k'),
        throwsA(isA<InternalException>()),
      );
    });
  });

  group('TranscriptionResult.fromJson', () {
    test('парсит все поля включая words', () {
      final r = TranscriptionResult.fromJson({
        'text': 'Hello world',
        'language': 'en',
        'duration': 3.5,
        'words': [
          {'word': 'Hello', 'start': 0.0, 'end': 0.4},
          {'word': 'world', 'start': 0.5, 'end': 0.9},
        ],
      });
      expect(r.text, 'Hello world');
      expect(r.language, 'en');
      expect(r.duration, 3.5);
      expect(r.words.length, 2);
    });

    test('ответ без поля words → пустой список', () {
      final r = TranscriptionResult.fromJson({
        'text': 'hello',
        'language': 'en',
        'duration': 1.0,
      });
      expect(r.words, isEmpty);
      expect(r.text, 'hello');
    });

    test('частично отсутствующие поля → дефолты', () {
      final r = TranscriptionResult.fromJson({});
      expect(r.text, '');
      expect(r.language, '');
      expect(r.duration, 0.0);
      expect(r.words, isEmpty);
    });
  });
}
