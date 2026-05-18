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

// ────────────────────────────────────────────────────────────────────────────
// GroqKeyPool
// ────────────────────────────────────────────────────────────────────────────

/// Пул Groq API-ключей с round-robin ротацией и поддержкой rate-limit блокировок.
///
/// Ключевые операции:
/// - [acquireKey] — возвращает следующий живой ключ (асинхронно ждёт если все заблокированы)
/// - [reportRateLimited] — помечает ключ заблокированным на N секунд
/// - [getStatuses] — возвращает текущий статус всех ключей для UI
///
/// Расширяет [ChangeNotifier]: UI слушает через ListenableBuilder без поллинга.
class GroqKeyPool extends ChangeNotifier {
  /// [initialKeys] — список сырых строк ключей для инициализации.
  GroqKeyPool({List<String> initialKeys = const []})
      : _keys = List.of(initialKeys);

  // Хранилище ключей
  final List<String> _keys;

  // Карта: ключ → время разблокировки (если ключ заблокирован)
  final Map<String, DateTime> _blockedUntil = {};

  // Текущий индекс round-robin
  int _cyclicIndex = 0;

  // Очередь ожидающих acquireKey()
  final List<Completer<String>> _waiters = [];

  // ── Геттеры ─────────────────────────────────────────────────────────────

  /// Количество незаблокированных ключей.
  int get aliveKeyCount => _keys.where((k) => !_isBlocked(k)).length;

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

  /// Возвращает следующий живой ключ по round-robin или null если все заблокированы.
  String? _nextAlive() {
    if (_keys.isEmpty) return null;
    // Защита от выхода за границы при удалении ключей
    _cyclicIndex = _cyclicIndex % _keys.length;
    for (var i = 0; i < _keys.length; i++) {
      final idx = (_cyclicIndex + i) % _keys.length;
      if (!_isBlocked(_keys[idx])) {
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

  /// Вызывается при пробуждении — раздаёт ключи ожидающим по одному.
  void _onWakeup() {
    if (_waiters.isEmpty) return;
    // Раздаём ключи waiters по одному через _nextAlive (не один ключ всем)
    while (_waiters.isNotEmpty) {
      final alive = _nextAlive();
      if (alive == null) {
        // Живых ключей ещё нет — перепланировать пробуждение
        _scheduleWakeup();
        break;
      }
      _waiters.removeAt(0).complete(alive);
    }
    notifyListeners();
  }

  // ── Публичный API ────────────────────────────────────────────────────────

  /// Возвращает следующий живой ключ (round-robin).
  /// Если все ключи заблокированы — ждёт разблокировки.
  /// Таймаут ожидания: 10 минут; при превышении бросает [AllKeysBlockedException].
  Future<String> acquireKey() async {
    final alive = _nextAlive();
    if (alive != null) return alive;

    // Все ключи заблокированы — ждём
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

  /// Освобождает ключ после использования.
  /// В текущей реализации ключи не требуют явного release (ротация через round-robin).
  void releaseKey(String key) {
    // Заглушка: явный release не нужен при round-robin подходе
  }

  /// Возвращает список статусов всех ключей для отображения в UI.
  List<KeyStatus> getStatuses() {
    return _keys.map((k) {
      if (_isBlocked(k)) {
        return BlockedKeyStatus(key: k, blockedUntil: _blockedUntil[k]!);
      }
      return ActiveKeyStatus(key: k);
    }).toList();
  }

  /// Возвращает статус конкретного ключа (для ApiKeysScreen).
  KeyStatus getStatusForKey(String rawKey) {
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
  void removeKey(String raw) {
    _keys.remove(raw);
    _blockedUntil.remove(raw);
    // Защита от выхода за границы после удаления
    if (_keys.isNotEmpty) {
      _cyclicIndex = _cyclicIndex % _keys.length;
    } else {
      _cyclicIndex = 0;
    }
    notifyListeners();
  }
}
