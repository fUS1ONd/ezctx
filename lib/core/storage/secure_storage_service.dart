import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:synchronized/synchronized.dart';

import '../constants/app_constants.dart';

/// Контракт для работы с защищённым хранилищем API-ключей.
abstract interface class SecureStorageService {
  @Deprecated(
    'Skeleton API — использовать addApiKey/listApiKeys/removeApiKey через ApiKeyRepository',
  )
  Future<void> writeRawKey(String value);

  @Deprecated(
    'Skeleton API — использовать addApiKey/listApiKeys/removeApiKey через ApiKeyRepository',
  )
  Future<String?> readRawKey();

  @Deprecated(
    'Skeleton API — использовать addApiKey/listApiKeys/removeApiKey через ApiKeyRepository',
  )
  Future<void> deleteRawKey();

  // Высокоуровневый API — multi-key ready (Phase 3).
  Future<List<String>> listApiKeys();
  Future<void> addApiKey(String key);
  Future<void> removeApiKey(String key);
}

/// Реализация SecureStorageService через flutter_secure_storage.
/// Все API-ключи хранятся под заданным namespace-ключом как JSON-массив строк.
/// [storageKey] задаёт namespace: default = Groq, для Deepgram передаётся явно.
class SecureStorageServiceImpl implements SecureStorageService {
  SecureStorageServiceImpl({
    FlutterSecureStorage? storage,
    String storageKey = AppConstants.storageKeyApiKeys,
<<<<<<< HEAD
  }) : _storage =
           storage ??
           const FlutterSecureStorage(
             aOptions: AndroidOptions(),
           ),
       _storageKey = storageKey;

  final FlutterSecureStorage _storage;
  final _lock = Lock();

  // Namespace ключа хранилища: определяет изоляцию Groq и Deepgram ключей (T-10-03)
  final String _storageKey;

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
    await _lock.synchronized(() async {
      final keys = await listApiKeys();
      if (!keys.contains(key)) {
        keys.add(key);
        await _storage.write(key: _storageKey, value: jsonEncode(keys));
      }
    });
  }

  @override
  Future<void> removeApiKey(String key) async {
    await _lock.synchronized(() async {
      final keys = await listApiKeys();
      keys.remove(key);
      await _storage.write(key: _storageKey, value: jsonEncode(keys));
    });
  }
}
