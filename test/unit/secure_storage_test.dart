// Тесты SecureStorageService.
// Используют FakeFlutterSecureStorage (без mockito code gen) для скорости.
// Покрывает KEYS-02 из REQUIREMENTS.md.
// Адаптировано под flutter_secure_storage 10.x API (AppleOptions вместо IOSOptions/MacOsOptions).
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ezctx/core/storage/secure_storage_service.dart';

/// Fake-реализация FlutterSecureStorage для тестов (in-memory).
/// Использует AppleOptions вместо IOSOptions/MacOsOptions (v10.x breaking change).
class FakeFlutterSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _store = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _store.remove(key);
    } else {
      _store[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _store[key];
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _store.remove(key);
  }
}

void main() {
  group('SecureStorageService', () {
    late FakeFlutterSecureStorage fakeStorage;
    late SecureStorageServiceImpl sut;

    setUp(() {
      fakeStorage = FakeFlutterSecureStorage();
      sut = SecureStorageServiceImpl(storage: fakeStorage);
    });

    test('writeRawKey then readRawKey returns same value', () async {
      await sut.writeRawKey('test-api-key-12345');
      final result = await sut.readRawKey();
      expect(result, equals('test-api-key-12345'));
    });

    test('readRawKey returns null when nothing stored', () async {
      final result = await sut.readRawKey();
      expect(result, isNull);
    });

    test('addApiKey appends to existing list', () async {
      // Предустановить существующий ключ
      await fakeStorage.write(key: 'groq_api_keys_v1', value: '["existing-key"]');
      await sut.addApiKey('new-key');
      final keys = await sut.listApiKeys();
      expect(keys, containsAll(['existing-key', 'new-key']));
      expect(keys.length, equals(2));
    });

    test('addApiKey is idempotent — duplicate key not added', () async {
      await sut.addApiKey('my-key');
      await sut.addApiKey('my-key'); // повторное добавление
      final keys = await sut.listApiKeys();
      expect(keys, equals(['my-key']));
      expect(keys.length, equals(1));
    });

    test('removeApiKey filters out specified key', () async {
      await sut.addApiKey('key-a');
      await sut.addApiKey('key-b');
      await sut.removeApiKey('key-a');
      final keys = await sut.listApiKeys();
      expect(keys, isNot(contains('key-a')));
      expect(keys, contains('key-b'));
    });
  });
}
