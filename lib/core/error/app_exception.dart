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
