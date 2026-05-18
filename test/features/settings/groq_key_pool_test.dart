import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

// ignore: unused_import
import 'package:ezctx/features/transcription/groq_key_pool.dart';

void main() {
  group('GroqKeyPool', () {
    test('round_robin выдаёт ключи по очереди', () {
      fail('RED — реализация ещё не написана');
    });

    test('заблокированный ключ пропускается при acquireKey', () {
      fail('RED — реализация ещё не написана');
    });

    test('все ключи заблокированы → ждём разблокировки', () {
      fail('RED — реализация ещё не написана');
    });

    test('таймаут 10 мин → AllKeysBlockedException', () {
      fakeAsync((async) {
        fail('RED — реализация ещё не написана');
      });
    });
  });
}
