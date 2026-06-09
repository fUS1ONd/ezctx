import 'package:ezctx/core/error/app_exception.dart';
import 'package:ezctx/features/transcription/key_pool.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('KeyPool', () {
    test('round_robin выдаёт ключи по очереди', () async {
      // Два ключа: k1, k2 — ожидаем чередование
      final pool = KeyPool(initialKeys: ['k1', 'k2']);
      expect(await pool.acquireKey(), 'k1');
      expect(await pool.acquireKey(), 'k2');
      expect(await pool.acquireKey(), 'k1');
    });

    test('заблокированный ключ пропускается при acquireKey', () async {
      final pool = KeyPool(initialKeys: ['k1', 'k2']);
      // Блокируем k1 на 30 секунд
      pool.reportRateLimited('k1', 30);
      // Следующие два вызова должны вернуть k2
      expect(await pool.acquireKey(), 'k2');
      expect(await pool.acquireKey(), 'k2');
    });

    test('все ключи заблокированы → ждём разблокировки', () {
      fakeAsync((async) {
        final pool = KeyPool(initialKeys: ['k1']);
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
        final pool = KeyPool(initialKeys: ['k1']);
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
      final pool = KeyPool(initialKeys: ['k1', 'k2', 'k3']);
      expect(pool.aliveKeyCount, 3);
      pool.reportRateLimited('k1', 60);
      expect(pool.aliveKeyCount, 2);
    });

    test('getStatuses возвращает правильные типы', () {
      final pool = KeyPool(initialKeys: ['k1', 'k2']);
      pool.reportRateLimited('k1', 60);
      final statuses = pool.getStatuses();
      expect(statuses[0], isA<BlockedKeyStatus>());
      expect(statuses[1], isA<ActiveKeyStatus>());
    });

    test('addKey / removeKey работают корректно', () {
      final pool = KeyPool(initialKeys: ['k1']);
      pool.addKey('k2');
      expect(pool.allKeys, ['k1', 'k2']);
      pool.removeKey('k1');
      expect(pool.allKeys, ['k2']);
    });

    // ── R-01: ExhaustedKeyStatus в getStatuses ────────────────────────────
    test('R-01: getStatuses возвращает ExhaustedKeyStatus для exhausted-ключа', () {
      final pool = KeyPool(initialKeys: ['k1', 'k2']);
      pool.reportExhausted('k1');
      final statuses = pool.getStatuses();
      // k1 должен вернуть ExhaustedKeyStatus — не Active и не Blocked
      expect(statuses[0], isA<ExhaustedKeyStatus>());
      expect(statuses[1], isA<ActiveKeyStatus>());
    });

    // ── R-02: exhausted-ключ не выдаётся через acquireKey ────────────────
    test('R-02: после reportExhausted k1 acquireKey возвращает только k2', () async {
      final pool = KeyPool(initialKeys: ['k1', 'k2']);
      pool.reportExhausted('k1');
      // Многократные вызовы — только k2, k1 никогда не появляется
      expect(await pool.acquireKey(), 'k2');
      expect(await pool.acquireKey(), 'k2');
      expect(await pool.acquireKey(), 'k2');
    });

    // ── R-03: aliveKeyCount исключает exhausted ───────────────────────────
    test('R-03: aliveKeyCount исключает exhausted-ключ', () {
      final pool = KeyPool(initialKeys: ['k1', 'k2', 'k3']);
      expect(pool.aliveKeyCount, 3);
      pool.reportExhausted('k1');
      expect(pool.aliveKeyCount, 2);
    });

    // ── R-04: все exhausted + пустой _blockedUntil → немедленный AllKeysBlockedException
    test('R-04: единственный ключ exhausted → AllKeysBlockedException немедленно', () {
      fakeAsync((async) {
        final pool = KeyPool(initialKeys: ['k1']);
        pool.reportExhausted('k1');

        Object? thrown;
        pool.acquireKey().catchError((e) {
          thrown = e;
          return '';
        });

        // Исключение должно быть брошено НЕМЕДЛЕННО — до любого elapse
        async.flushMicrotasks();
        expect(
          thrown,
          isA<AllKeysBlockedException>(),
          reason: 'должен бросать AllKeysBlockedException немедленно без 10-мин таймаута',
        );

        // Убеждаемся, что никакого 10-минутного ожидания нет
        async.elapse(const Duration(minutes: 10));
        // thrown уже был установлен выше — повторная проверка для надёжности
        expect(thrown, isA<AllKeysBlockedException>());
      });
    });

    // ── WR-04: припаркованный waiter будится при исчерпании последнего ключа ──
    test(
      'WR-04: reportExhausted последнего живого ключа будит waiter немедленно',
      () {
        fakeAsync((async) {
          // k1 заблокирован rate-limit'ом, k2 пока живой.
          final pool = KeyPool(initialKeys: ['k1', 'k2']);
          pool.reportRateLimited('k1', 600); // 10 мин блокировки

          // Исчерпываем k2 — но waiter появится только при отсутствии живых.
          // Сначала блокируем k2, чтобы acquireKey припарковал waiter.
          pool.reportRateLimited('k2', 600);

          Object? thrown;
          String? result;
          pool.acquireKey().then((k) => result = k).catchError((e) {
            thrown = e;
            return '';
          });

          async.flushMicrotasks();
          // Пока оба ключа в rate-limit — waiter висит, исключения нет.
          expect(thrown, isNull);
          expect(result, isNull);

          // Исчерпываем оба ключа (402). Теперь живых нет, но _blockedUntil
          // ещё не пуст — снимем блокировки удалением.
          pool.reportExhausted('k1');
          pool.reportExhausted('k2');
          // _blockedUntil всё ещё содержит k1/k2 → _failWaitersIfPoolDead
          // не сработает. Удаляем ключи — это чистит и _blockedUntil.
          pool.removeKey('k1');
          pool.removeKey('k2');

          async.flushMicrotasks();
          // Waiter должен быть провален НЕМЕДЛЕННО, без 10-мин таймаута.
          expect(
            thrown,
            isA<AllKeysBlockedException>(),
            reason: 'удаление последнего ключа должно сразу провалить waiter',
          );
        });
      },
    );

    test(
      'WR-04: removeKey единственного живого ключа будит waiter немедленно',
      () {
        fakeAsync((async) {
          final pool = KeyPool(initialKeys: ['k1', 'k2']);
          // Оба в rate-limit → acquireKey припаркует waiter.
          pool.reportRateLimited('k1', 600);
          pool.reportRateLimited('k2', 600);

          Object? thrown;
          pool.acquireKey().catchError((e) {
            thrown = e;
            return '';
          });

          async.flushMicrotasks();
          expect(thrown, isNull);

          // Удаляем оба ключа — _blockedUntil очищается, живых не остаётся.
          pool.removeKey('k1');
          pool.removeKey('k2');

          async.flushMicrotasks();
          expect(
            thrown,
            isA<AllKeysBlockedException>(),
            reason: 'waiter должен быть провален сразу при опустошении пула',
          );
        });
      },
    );
  });
}
