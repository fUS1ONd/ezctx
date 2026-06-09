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
/// Бросается из KeyPool.acquireKey() после 10 минут ожидания живого ключа.
class AllKeysBlockedException extends AppException {
  const AllKeysBlockedException([
    super.message = 'Все ключи заблокированы. Ожидание…',
  ]);
}

/// Кредиты API-ключа провайдера исчерпаны — ключ выводится из ротации навсегда.
/// Deepgram: HTTP 402. Groq: никогда не бросает это исключение.
/// Не содержит значение ключа — сообщение статично (T-09-01-I).
class KeyExhaustedException extends AppException {
  const KeyExhaustedException([
    super.message = 'Кредиты API-ключа исчерпаны.',
  ]);
}

/// Человекочитаемые сообщения для отображения ошибок пользователю.
extension AppExceptionUserMessage on AppException {
  String get userMessage => switch (this) {
    RateLimitException(:final retryAfterSeconds) =>
        'Превышен лимит Groq. Попробуйте через $retryAfterSeconds с.',
    AllKeysBlockedException() =>
        'Все API-ключи заблокированы лимитом. Подождите или добавьте ещё ключи.',
    KeyExhaustedException() =>
        'Кредиты API-ключа исчерпаны. Добавьте ключ с активным балансом.',
    AuthException() =>
        'Неверный API-ключ. Проверьте настройки.',
    NetworkException() =>
        'Нет подключения к интернету.',
    ValidationException(:final message) => message,
    InternalException() =>
        'Внутренняя ошибка. Попробуйте ещё раз.',
  };
}
