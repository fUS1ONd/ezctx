import 'package:ezctx/core/error/app_exception.dart';
import 'package:ezctx/features/transcription/groq_api_service.dart';
import 'package:ezctx/features/transcription/groq_key_pool.dart';
import 'package:ezctx/features/transcription/selected_audio_file.dart';
import 'package:ezctx/features/transcription/transcription_controller.dart';
import 'package:ezctx/features/transcription/transcription_result.dart';
import 'package:flutter_test/flutter_test.dart';

// Stub GroqApiService: результат или исключение задаётся через handler.
class _StubGroqService extends GroqApiService {
  final Future<TranscriptionResult> Function(SelectedAudioFile, String) _handler;
  _StubGroqService(this._handler) : super();

  @override
  Future<TranscriptionResult> transcribe({
    required SelectedAudioFile file,
    required String apiKey,
  }) => _handler(file, apiKey);
}

const _file = SelectedAudioFile(
  path: '/tmp/lecture.mp3',
  name: 'lecture.mp3',
  sizeBytes: 1024 * 1024,
  extension: 'mp3',
);

const _ok = TranscriptionResult(
  text: 'Привет мир',
  language: 'russian',
  duration: 3.0,
  words: [],
);

TranscriptionController _make({
  List<String> keys = const [],
  Future<TranscriptionResult> Function(SelectedAudioFile, String)? groq,
}) {
  final pool = GroqKeyPool(initialKeys: List.of(keys));
  final api = _StubGroqService(groq ?? (_, __) async => _ok);
  return TranscriptionController(pool: pool, apiService: api);
}

void main() {
  group('TranscriptionController — состояния (TRANS-03, TRANS-07)', () {
    test('нет API-ключей → TranscriptionMissingKey', () async {
      final ctrl = _make(keys: []);
      await ctrl.start(_file);
      expect(ctrl.state, isA<TranscriptionMissingKey>());
    });

    test('успешный ответ Groq → TranscriptionSuccess с правильным текстом', () async {
      final ctrl = _make(keys: ['gsk_${'a' * 30}']);
      await ctrl.start(_file);
      expect(ctrl.state, isA<TranscriptionSuccess>());
      expect((ctrl.state as TranscriptionSuccess).result.text, 'Привет мир');
    });

    test('первый ключ из списка передаётся в apiKey', () async {
      String? usedKey;
      final ctrl = _make(
        keys: ['gsk_first${'a' * 22}', 'gsk_second${'b' * 21}'],
        groq: (_, k) async { usedKey = k; return _ok; },
      );
      await ctrl.start(_file);
      expect(usedKey, 'gsk_first${'a' * 22}');
    });

    test('AuthException → TranscriptionError retryable:false (TRANS-03)', () async {
      final ctrl = _make(
        keys: ['gsk_${'a' * 30}'],
        groq: (_, __) => Future.error(const AuthException('bad key')),
      );
      await ctrl.start(_file);
      final s = ctrl.state as TranscriptionError;
      expect(s.retryable, isFalse);
    });

    test('NetworkException → TranscriptionError retryable:true (TRANS-07)', () async {
      final ctrl = _make(
        keys: ['gsk_${'a' * 30}'],
        groq: (_, __) => Future.error(const NetworkException('no internet')),
      );
      await ctrl.start(_file);
      final s = ctrl.state as TranscriptionError;
      expect(s.retryable, isTrue);
    });

    test('InternalException → TranscriptionError retryable:true', () async {
      final ctrl = _make(
        keys: ['gsk_${'a' * 30}'],
        groq: (_, __) => Future.error(const InternalException('parse fail')),
      );
      await ctrl.start(_file);
      final s = ctrl.state as TranscriptionError;
      expect(s.retryable, isTrue);
    });

    test('неизвестное исключение → TranscriptionError retryable:true', () async {
      final ctrl = _make(
        keys: ['gsk_${'a' * 30}'],
        groq: (_, __) => Future.error(Exception('random')),
      );
      await ctrl.start(_file);
      final s = ctrl.state as TranscriptionError;
      expect(s.retryable, isTrue);
    });

    test('start() немедленно переходит в TranscriptionLoading', () async {
      final states = <TranscriptionState>[];
      final ctrl = _make(
        keys: ['gsk_${'a' * 30}'],
        groq: (_, __) async {
          await Future.delayed(const Duration(milliseconds: 10));
          return _ok;
        },
      );
      ctrl.addListener(() => states.add(ctrl.state));
      await ctrl.start(_file);
      expect(states.first, isA<TranscriptionLoading>());
      expect(states.last, isA<TranscriptionSuccess>());
    });
  });
}
