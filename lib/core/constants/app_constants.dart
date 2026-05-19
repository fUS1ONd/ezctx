/// Глобальные константы приложения.
/// Источник правды для endpoint-ов, лимитов и whitelist-ов.
class AppConstants {
  AppConstants._();

  // Groq Whisper API
  static const String groqApiUrl =
      'https://api.groq.com/openai/v1/audio/transcriptions';
  static const String groqDefaultModel = 'whisper-large-v3';
  static const String groqTurboModel = 'whisper-large-v3-turbo';
  static const String groqResponseFormat = 'verbose_json';
  // segment, а не word: при 'word' Groq не всегда возвращает segments[],
  // и переключатель «С метками / Без меток» на ResultScreen теряет разницу.
  // Chunked-путь хардкодит 'segment' в groq_api_service.dart (там не нужны word-таймкоды).
  static const String groqTimestampGranularity = 'segment';

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

  /// Порог для isChunked и нарезки чанков: 82 мин ≈ 18.7 MB при 32 kbps (per D-PHASE09).
  static const int kChunkThresholdSeconds = 4920;

  /// Максимальное число параллельных чанков.
  /// Реальное значение = min(pool.aliveKeyCount, этой константы).
  static const int kMaxConcurrentChunks = 5;

  // Secure storage keys
  static const String storageKeyApiKeys = 'groq_api_keys_v1';
  static const String storageKeyTranscriptionOptions = 'transcription_options_v1';

  // Маршруты приложения
  static const String routeHome = '/';
  static const String routeSettings = '/settings';
  static const String routeApiKeys = '/settings/api-keys';
  static const String routeProcessing = '/processing';
  static const String routeResult = '/result';
}
