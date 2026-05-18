/// Базовое исключение приложения.
/// Используется UI-слоем для отображения человекочитаемых сообщений.
sealed class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

/// Сетевая ошибка (нет соединения, таймаут, 5xx от Groq).
class NetworkException extends AppException {
  const NetworkException(super.message);
}

/// Ошибка аутентификации (401 от Groq — неверный API-ключ).
class AuthException extends AppException {
  const AuthException(super.message);
}

/// Ошибка валидации входных данных (формат файла, размер).
class ValidationException extends AppException {
  const ValidationException(super.message);
}

/// Внутренняя ошибка (парсинг JSON, неожиданный формат ответа).
class InternalException extends AppException {
  const InternalException(super.message);
}

/// HTTP 429 от Groq — превышен rate limit; ретраится с задержкой.
/// [retryAfterSeconds] — количество секунд до следующего разрешённого запроса.
/// Парсится из заголовков retry-after / x-ratelimit-reset-*; дефолт 60 с.
class RateLimitException extends AppException {
  final int retryAfterSeconds;
  const RateLimitException(super.message, {this.retryAfterSeconds = 60});
}

/// Все API-ключи заблокированы rate-limit'ом и таймаут ожидания истёк.
/// Бросается из GroqKeyPool.acquireKey() после 10 минут ожидания живого ключа.
class AllKeysBlockedException extends AppException {
  const AllKeysBlockedException([
    super.message = 'Все ключи заблокированы. Ожидание…',
  ]);
}
