import 'package:ezctx/core/error/app_exception.dart';
import 'package:ezctx/core/storage/secure_storage_service.dart';
import 'package:ezctx/features/settings/api_key_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeStorage implements SecureStorageService {
  final List<String> _keys = [];

  @override
  Future<List<String>> listApiKeys() async => List.unmodifiable(_keys);

  @override
  Future<void> addApiKey(String key) async {
    if (!_keys.contains(key)) _keys.add(key);
  }

  @override
  Future<void> removeApiKey(String key) async => _keys.remove(key);

  @override
  // ignore: deprecated_member_use_from_same_package
  Future<void> writeRawKey(String value) async {}
  @override
  // ignore: deprecated_member_use_from_same_package
  Future<String?> readRawKey() async => null;
  @override
  // ignore: deprecated_member_use_from_same_package
  Future<void> deleteRawKey() async {}
}

void main() {
  late ApiKeyRepository repo;
  late _FakeStorage storage;

  setUp(() {
    storage = _FakeStorage();
    repo = ApiKeyRepository(storage);
  });

  group('addKey', () {
    test('добавляет валидный ключ', () async {
      await repo.addKey('gsk_${'a' * 30}');
      final keys = await repo.listKeys();
      expect(keys.length, 1);
    });

    test('пустая строка → ValidationException', () async {
      expect(() => repo.addKey(''), throwsA(isA<ValidationException>()));
    });

    test('строка только из пробелов → ValidationException', () async {
      expect(() => repo.addKey('   '), throwsA(isA<ValidationException>()));
    });

    test('короткий ключ → ValidationException', () async {
      expect(() => repo.addKey('short'), throwsA(isA<ValidationException>()));
    });

    test('trim пробелов перед сохранением', () async {
      await repo.addKey('  gsk_${'x' * 30}  ');
      final keys = await repo.listKeys();
      expect(keys.first.raw.startsWith(' '), isFalse);
      expect(keys.first.raw.endsWith(' '), isFalse);
    });

    test('идемпотентность — дубликат не добавляется', () async {
      final k = 'gsk_${'y' * 30}';
      await repo.addKey(k);
      await repo.addKey(k);
      final keys = await repo.listKeys();
      expect(keys.length, 1);
    });
  });

  group('removeKey', () {
    test('удаляет указанный ключ', () async {
      final k = 'gsk_${'z' * 30}';
      await repo.addKey(k);
      await repo.removeKey(k);
      final keys = await repo.listKeys();
      expect(keys, isEmpty);
    });
  });

  group('mask', () {
    test('последние 4 символа видны, середина точками', () {
      final masked = ApiKeyRepository.mask('gsk_abcdefghijklmnopqrstuvWXYZ1234');
      expect(masked.endsWith('1234'), isTrue);
      expect(masked.contains('•'), isTrue);
      expect(masked.contains('gsk_'), isFalse);
    });

    test('слишком короткий ключ полностью скрыт', () {
      expect(ApiKeyRepository.mask('abc'), '••••••••');
    });
  });
}
