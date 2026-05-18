/// Глобальные константы приложения.
/// Источник правды для endpoint-ов, лимитов и whitelist-ов.
class AppConstants {
  AppConstants._();

  // Groq Whisper API
  static const String groqApiUrl =
      'https://api.groq.com/openai/v1/audio/transcriptions';
  static const String groqDefaultModel = 'whisper-large-v3';
  static const String groqResponseFormat = 'verbose_json';
  static const String groqTimestampGranularity = 'word';

  // Лимиты файлов
  // 19 MB — консервативная граница; реальный лимит Groq Free Tier = 25 MB.
  // В Phase 1 файлы > 19 MB отклоняются с ошибкой; чанкование появится в Phase 2.
  static const int maxFileSizeBytes = 19 * 1024 * 1024;

  // Whitelist расширений по Groq API.
  static const Set<String> supportedAudioExtensions = {
    'flac',
    'mp3',
    'mp4',
    'mpeg',
    'mpga',
    'm4a',
    'ogg',
    'wav',
    'webm',
  };

  /// Порог для isChunked: длительность нормализованного mp3 > 75 мин = 4500 с (per D3).
  static const int kChunkThresholdSeconds = 4500;

  /// Длительность одного чанка при нарезке нормализованного mp3 (per D3).
  /// 75 мин × 240 КБ/мин ≈ 17.6 МБ < 19 МБ лимита Groq.
  static const double kChunkDurationSeconds = 4500.0;

  /// Максимальное число параллельных чанков.
  /// Реальное значение = min(pool.aliveKeyCount, этой константы).
  static const int kMaxConcurrentChunks = 5;

  // Secure storage keys
  static const String storageKeyApiKeys = 'groq_api_keys_v1';

  // Маршруты приложения
  static const String routeHome = '/';
  static const String routeSettings = '/settings';
  static const String routeApiKeys = '/settings/api-keys';
  static const String routeProcessing = '/processing';
  static const String routeResult = '/result';
}
