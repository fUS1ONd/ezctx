import 'dart:async';

import 'package:ezctx/core/error/app_exception.dart';
import 'package:ezctx/features/transcription/groq_key_pool.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GroqKeyPool', () {
    test('round_robin выдаёт ключи по очереди', () async {
      // Два ключа: k1, k2 — ожидаем чередование
      final pool = GroqKeyPool(initialKeys: ['k1', 'k2']);
      expect(await pool.acquireKey(), 'k1');
      expect(await pool.acquireKey(), 'k2');
      expect(await pool.acquireKey(), 'k1');
    });

    test('заблокированный ключ пропускается при acquireKey', () async {
      final pool = GroqKeyPool(initialKeys: ['k1', 'k2']);
      // Блокируем k1 на 30 секунд
      pool.reportRateLimited('k1', 30);
      // Следующие два вызова должны вернуть k2
      expect(await pool.acquireKey(), 'k2');
      expect(await pool.acquireKey(), 'k2');
    });

    test('все ключи заблокированы → ждём разблокировки', () {
      fakeAsync((async) {
        final pool = GroqKeyPool(initialKeys: ['k1']);
        // Блокируем единственный ключ на 5 секунд
        pool.reportRateLimited('k1', 5);

        String? result;
        pool.acquireKey().then((key) => result = key);

        // До истечения блокировки — ключ ещё не получен
        async.elapse(const Duration(seconds: 4));
        expect(result, isNull);

        // После истечения блокировки — ключ получен
        async.elapse(const Duration(seconds: 2));
        expect(result, 'k1');
      });
    });

    test('таймаут 10 мин → AllKeysBlockedException', () {
      fakeAsync((async) {
        final pool = GroqKeyPool(initialKeys: ['k1']);
        // Блокируем на 20 минут (больше таймаута acquireKey = 10 мин)
        pool.reportRateLimited('k1', 1200);

        Object? thrown;
        pool.acquireKey().catchError((e) {
          thrown = e;
          return '';
        });

        // До таймаута — исключение не брошено
        async.elapse(const Duration(minutes: 9));
        expect(thrown, isNull);

        // После 10+ минут — AllKeysBlockedException
        async.elapse(const Duration(minutes: 2));
        expect(thrown, isA<AllKeysBlockedException>());
      });
    });

    test('aliveKeyCount корректен', () {
      final pool = GroqKeyPool(initialKeys: ['k1', 'k2', 'k3']);
      expect(pool.aliveKeyCount, 3);
      pool.reportRateLimited('k1', 60);
      expect(pool.aliveKeyCount, 2);
    });

    test('getStatuses возвращает правильные типы', () {
      final pool = GroqKeyPool(initialKeys: ['k1', 'k2']);
      pool.reportRateLimited('k1', 60);
      final statuses = pool.getStatuses();
      expect(statuses[0], isA<BlockedKeyStatus>());
      expect(statuses[1], isA<ActiveKeyStatus>());
    });

    test('addKey / removeKey работают корректно', () {
      final pool = GroqKeyPool(initialKeys: ['k1']);
      pool.addKey('k2');
      expect(pool.allKeys, ['k1', 'k2']);
      pool.removeKey('k1');
      expect(pool.allKeys, ['k2']);
    });
  });
}
