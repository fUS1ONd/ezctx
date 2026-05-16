import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/app_constants.dart';

/// Контракт для работы с защищённым хранилищем API-ключей.
abstract interface class SecureStorageService {
  // Низкоуровневый API — для skeleton-кнопки в ApiKeysScreen.
  // Будет удалён в Plan 02, заменён на addApiKey/listApiKeys/removeApiKey.
  Future<void> writeRawKey(String value);
  Future<String?> readRawKey();
  Future<void> deleteRawKey();

  // Высокоуровневый API — multi-key ready (Phase 3).
  Future<List<String>> listApiKeys();
  Future<void> addApiKey(String key);
  Future<void> removeApiKey(String key);
}

/// Реализация SecureStorageService через flutter_secure_storage.
/// Все API-ключи хранятся под единым ключом как JSON-массив строк.
class SecureStorageServiceImpl implements SecureStorageService {
  SecureStorageServiceImpl({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(),
          );

  final FlutterSecureStorage _storage;

  // Используем константу, не магическую строку (T-01-01: нет логирования ключей)
  static const _storageKey = AppConstants.storageKeyApiKeys;

  @override
  Future<void> writeRawKey(String value) async {
    await _storage.write(key: _storageKey, value: value);
  }

  @override
  Future<String?> readRawKey() async {
    return _storage.read(key: _storageKey);
  }

  @override
  Future<void> deleteRawKey() async {
    await _storage.delete(key: _storageKey);
  }

  @override
  Future<List<String>> listApiKeys() async {
    final raw = await _storage.read(key: _storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<String>().toList();
      }
    } catch (_) {
      // Если данные не JSON-массив — возвращаем пустой список
    }
    return [];
  }

  @override
  Future<void> addApiKey(String key) async {
    final keys = await listApiKeys();
    if (!keys.contains(key)) {
      keys.add(key);
      await _storage.write(key: _storageKey, value: jsonEncode(keys));
    }
  }

  @override
  Future<void> removeApiKey(String key) async {
    final keys = await listApiKeys();
    keys.remove(key);
    await _storage.write(key: _storageKey, value: jsonEncode(keys));
  }
}
