import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import '../../core/error/app_exception.dart';

// ────────────────────────────────────────────────────────────────────────────
// Статус ключа
// ────────────────────────────────────────────────────────────────────────────

/// Базовый sealed-класс статуса API-ключа.
sealed class KeyStatus {
  final String key;
  const KeyStatus({required this.key});
}

/// Ключ активен и доступен для запросов.
final class ActiveKeyStatus extends KeyStatus {
  const ActiveKeyStatus({required super.key});
}

/// Ключ заблокирован rate-limit'ом до указанного момента.
final class BlockedKeyStatus extends KeyStatus {
  final DateTime blockedUntil;
  const BlockedKeyStatus({required super.key, required this.blockedUntil});
}

/// Ключ навсегда выведен из ротации — кредиты провайдера исчерпаны.
/// Deepgram: HTTP 402. Устанавливается через [KeyPool.reportExhausted].
/// Не снимается таймером — только через [KeyPool.removeKey].
final class ExhaustedKeyStatus extends KeyStatus {
  const ExhaustedKeyStatus({required super.key});
}

// ────────────────────────────────────────────────────────────────────────────
// KeyPool
// ────────────────────────────────────────────────────────────────────────────

/// Пул API-ключей с round-robin ротацией и поддержкой rate-limit блокировок.
///
/// Провайдеро-независим: одинаково используется Groq и Deepgram клиентами.
///
/// Ключевые операции:
/// - [acquireKey] — возвращает следующий живой ключ (асинхронно ждёт если все заблокированы)
/// - [reportRateLimited] — помечает ключ заблокированным на N секунд
/// - [reportExhausted] — навсегда выводит ключ из ротации (исчерпанные кредиты)
/// - [getStatuses] — возвращает текущий статус всех ключей для UI
///
/// Расширяет [ChangeNotifier]: UI слушает через ListenableBuilder без поллинга.
class KeyPool extends ChangeNotifier {
  /// [initialKeys] — список сырых строк ключей для инициализации.
  KeyPool({List<String> initialKeys = const []})
      : _keys = List.of(initialKeys);

  // Хранилище ключей
  final List<String> _keys;

  // Карта: ключ → время разблокировки (если ключ заблокирован)
  final Map<String, DateTime> _blockedUntil = {};

  // Множество ключей с исчерпанными кредитами — навсегда выведены из ротации
  final Set<String> _exhausted = {};

  // Текущий индекс round-robin
  int _cyclicIndex = 0;

  // Очередь ожидающих acquireKey()
  final List<Completer<String>> _waiters = [];

  // ── Геттеры ─────────────────────────────────────────────────────────────

  /// Количество живых ключей (не заблокированных и не исчерпанных).
  int get aliveKeyCount => _keys.where(_isAlive).length;

  /// Все ключи пула (включая заблокированные).
  List<String> get allKeys => List.unmodifiable(_keys);

  // ── Внутренние методы ────────────────────────────────────────────────────

  /// Проверяет, заблокирован ли ключ. Автоматически снимает истёкшие блокировки.
  bool _isBlocked(String key) {
    final until = _blockedUntil[key];
    if (until == null) return false;
    if (clock.now().isAfter(until)) {
      _blockedUntil.remove(key);
      return false;
    }
    return true;
  }

  /// Проверяет, является ли ключ «живым» — не заблокированным и не исчерпанным.
  /// Используется вместо !_isBlocked во всех местах выбора ключа.
  bool _isAlive(String key) => !_exhausted.contains(key) && !_isBlocked(key);

  /// Возвращает следующий живой ключ по round-robin или null если все заблокированы/исчерпаны.
  String? _nextAlive() {
    if (_keys.isEmpty) return null;
    // Защита от выхода за границы при удалении ключей
    _cyclicIndex = _cyclicIndex % _keys.length;
    for (var i = 0; i < _keys.length; i++) {
      final idx = (_cyclicIndex + i) % _keys.length;
      if (_isAlive(_keys[idx])) {
        // Advance: следующий acquireKey начнёт с idx+1
        _cyclicIndex = (idx + 1) % _keys.length;
        return _keys[idx];
      }
    }
    return null;
  }

  /// Планирует пробуждение при разблокировке ближайшего ключа.
  void _scheduleWakeup() {
    final now = clock.now();
    DateTime? nearest;
    for (final t in _blockedUntil.values) {
      if (t.isAfter(now)) {
        if (nearest == null || t.isBefore(nearest)) nearest = t;
      }
    }
    if (nearest == null) return;
    final delay = nearest.difference(now) + const Duration(milliseconds: 50);
    Timer(delay, _onWakeup);
  }

  /// Вызывается при пробуждении — выдаёт ровно один ключ одному ожидающему.
  ///
  /// После complete() цикл прерывается. Обработчик acquireKey() вернётся
  /// к вызывающему коду; если потребуется ещё ключ — acquireKey() снова добавит
  /// waiter и вызовет _scheduleWakeup(). Это предотвращает «шторм 429»: один и
  /// тот же единственный разблокированный ключ не раздаётся сразу всем ожидающим.
  void _onWakeup() {
    if (_waiters.isEmpty) return;
    final alive = _nextAlive();
    if (alive == null) {
      // Живых ключей ещё нет — перепланировать пробуждение.
      _scheduleWakeup();
      notifyListeners();
      return;
    }
    // Выдаём ключ ровно одному waiter'у и выходим.
    _waiters.removeAt(0).complete(alive);
    notifyListeners();
  }

  /// Немедленно проваливает всех припаркованных waiter'ов, если живых ключей
  /// не осталось и нет временных rate-limit блокировок (ждать больше нечего).
  ///
  /// Зеркалит быстрый путь R-04 из [acquireKey]: при опустошении пула
  /// (removeKey/reportExhausted последнего ключа) waiter не должен висеть
  /// 10 минут до таймаута — корректнее сразу бросить [AllKeysBlockedException].
  void _failWaitersIfPoolDead() {
    if (aliveKeyCount == 0 && _blockedUntil.isEmpty && _waiters.isNotEmpty) {
      for (final w in _waiters) {
        if (!w.isCompleted) {
          w.completeError(const AllKeysBlockedException(
            'Кредиты всех API-ключей исчерпаны. Добавьте ключ с активным балансом.',
          ));
        }
      }
      _waiters.clear();
    }
  }

  // ── Публичный API ────────────────────────────────────────────────────────

  /// Возвращает следующий живой ключ (round-robin).
  /// Если все ключи заблокированы rate-limit'ом — ждёт разблокировки.
  /// Если все ключи exhausted (и нет rate-limit блокировок) — бросает
  /// [AllKeysBlockedException] НЕМЕДЛЕННО, без 10-минутного ожидания.
  /// Таймаут ожидания: 10 минут; при превышении бросает [AllKeysBlockedException].
  Future<String> acquireKey() async {
    final alive = _nextAlive();
    if (alive != null) return alive;

    // Быстрый путь R-04: все ключи exhausted и нет временных блокировок —
    // ждать нечего, бросаем немедленно без создания waiter/_scheduleWakeup.
    // Анти-паттерн: НЕ добавлять exhausted в _blockedUntil — сломает _scheduleWakeup.
    if (_blockedUntil.isEmpty) {
      throw const AllKeysBlockedException(
        'Кредиты всех API-ключей исчерпаны. Добавьте ключ с активным балансом.',
      );
    }

    // Все ключи заблокированы rate-limit'ом — ждём
    final completer = Completer<String>();
    _waiters.add(completer);
    _scheduleWakeup();

    return completer.future.timeout(
      const Duration(minutes: 10),
      onTimeout: () {
        _waiters.remove(completer);
        throw const AllKeysBlockedException();
      },
    );
  }

  /// Помечает ключ заблокированным на [retryAfterSeconds] секунд.
  /// Вызывается при получении HTTP 429 от Groq API.
  void reportRateLimited(String key, int retryAfterSeconds) {
    // Безопасность T-04-01: маскируем ключ в логах
    debugPrint(
      'reportRateLimited: ...${key.length > 4 ? key.substring(key.length - 4) : key} '
      'на $retryAfterSeconds с',
    );
    _blockedUntil[key] =
        clock.now().add(Duration(seconds: retryAfterSeconds));
    notifyListeners();
    _scheduleWakeup();
  }

  /// Навсегда выводит ключ из ротации — кредиты исчерпаны (Deepgram HTTP 402).
  ///
  /// В отличие от [reportRateLimited], НЕ использует таймер и НЕ вызывает
  /// _scheduleWakeup — ключ остаётся exhausted до [removeKey].
  /// Безопасность T-09-02-I: маскируем ключ в логах (последние ≤4 символа).
  void reportExhausted(String key) {
    debugPrint(
      'reportExhausted: ...${key.length > 4 ? key.substring(key.length - 4) : key}',
    );
    _exhausted.add(key);
    // Если это был последний живой ключ и нет rate-limit блокировок —
    // будить нечем, поэтому сразу проваливаем припаркованных waiter'ов (WR-04).
    _failWaitersIfPoolDead();
    notifyListeners();
  }

  /// Освобождает ключ после использования.
  /// В текущей реализации ключи не требуют явного release (ротация через round-robin).
  void releaseKey(String key) {
    // Заглушка: явный release не нужен при round-robin подходе
  }

  /// Возвращает список статусов всех ключей для отображения в UI.
  List<KeyStatus> getStatuses() {
    return _keys.map((k) {
      // Сначала проверяем exhausted — приоритет выше rate-limit
      if (_exhausted.contains(k)) return ExhaustedKeyStatus(key: k);
      if (_isBlocked(k)) {
        return BlockedKeyStatus(key: k, blockedUntil: _blockedUntil[k]!);
      }
      return ActiveKeyStatus(key: k);
    }).toList();
  }

  /// Возвращает статус конкретного ключа (для ApiKeysScreen).
  KeyStatus getStatusForKey(String rawKey) {
    // Сначала проверяем exhausted — приоритет выше rate-limit
    if (_exhausted.contains(rawKey)) return ExhaustedKeyStatus(key: rawKey);
    if (_isBlocked(rawKey)) {
      return BlockedKeyStatus(
        key: rawKey,
        blockedUntil: _blockedUntil[rawKey]!,
      );
    }
    return ActiveKeyStatus(key: rawKey);
  }

  /// Добавляет ключ в пул (если его ещё нет).
  void addKey(String raw) {
    if (!_keys.contains(raw)) {
      _keys.add(raw);
      notifyListeners();
    }
  }

  /// Удаляет ключ из пула.
  /// Очищает все состояния ключа: _blockedUntil и _exhausted.
  void removeKey(String raw) {
    _keys.remove(raw);
    _blockedUntil.remove(raw);
    _exhausted.remove(raw);
    // Защита от выхода за границы после удаления
    if (_keys.isNotEmpty) {
      _cyclicIndex = _cyclicIndex % _keys.length;
    } else {
      _cyclicIndex = 0;
    }
    // Удалили последний живой ключ при отсутствии rate-limit блокировок —
    // припаркованные waiter'ы не дождутся пробуждения, проваливаем их сразу (WR-04).
    _failWaitersIfPoolDead();
    notifyListeners();
  }
}
