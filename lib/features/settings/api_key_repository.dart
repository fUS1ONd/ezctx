import '../../core/error/app_exception.dart';
import '../../core/storage/secure_storage_service.dart';

/// View-модель ключа: полное значение + готовое для UI маскированное представление.
class ApiKeyView {
  final String raw;
  final String masked;
  const ApiKeyView({required this.raw, required this.masked});
}

/// Repository для управления API-ключами провайдера (namespace задаётся SecureStorageService).
/// Единственный потребитель SecureStorageService в feature-слое.
class ApiKeyRepository {
  ApiKeyRepository(this._storage);

  final SecureStorageService _storage;

  // Минимальная длина — защита от случайного ввода; реальные Groq ключи 50+ символов.
  static const int _minKeyLength = 20;

  Future<List<ApiKeyView>> listKeys() async {
    final raw = await _storage.listApiKeys();
    return raw.map((k) => ApiKeyView(raw: k, masked: mask(k))).toList();
  }

  Future<void> addKey(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException('Ключ не может быть пустым');
    }
    if (trimmed.length < _minKeyLength) {
      throw const ValidationException(
        'Ключ слишком короткий (минимум $_minKeyLength символов)',
      );
    }
    await _storage.addApiKey(trimmed);
  }

  Future<void> removeKey(String value) async {
    await _storage.removeApiKey(value);
  }

  /// Маскирует ключ: последние 4 символа видны для идентификации, остальное — точки.
  static String mask(String key) {
    if (key.length < 8) {
      return '•' * 8;
    }
    final tail = key.substring(key.length - 4);
    return '${'•' * 16}$tail';
  }
}
