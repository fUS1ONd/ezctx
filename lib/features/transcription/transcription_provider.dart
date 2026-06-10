import 'transcription_options.dart';
import 'transcription_result.dart';

/// Провайдеро-независимый интерфейс транскрибации.
///
/// Это единственное место, которое должно знать специфику конкретного API:
/// URL запроса, формат тела (multipart vs raw), MIME-тип аудио, набор
/// параметров запроса, парсинг ответа в [TranscriptionResult] и маппинг
/// HTTP-кодов ответа в нормализованные исключения приложения
/// ([AuthException]/[NetworkException]/[RateLimitException]/[InternalException] —
/// см. lib/core/error/app_exception.dart). Контроллер и пул ключей работают
/// только с этим интерфейсом и не знают о специфике конкретного провайдера.
///
/// Важно: метод single-shot `transcribe(SelectedAudioFile ...)` сюда
/// НЕ входит — это узкоспециализированный путь только Groq (Phase 1),
/// чанкованный путь через [transcribeChunk] — общий контракт для всех
/// провайдеров (в т.ч. будущего Deepgram).
///
/// Сигнатуры спроектированы так, чтобы будущий `DeepgramProvider`
/// (Phase 10) встал без изменения сигнатур: `List<int> bytes` одинаково
/// подходит и для multipart-обёртки (Groq), и для передачи raw-байт
/// (Deepgram).
abstract interface class TranscriptionProvider {
  /// Транскрибация одного чанка аудио из байт.
  ///
  /// [bytes] — содержимое аудио-чанка, [filename] — имя файла для
  /// multipart-обёртки (если применимо провайдером), [apiKey] — ключ из
  /// пула ключей (передаётся аргументом, провайдер его не персистит),
  /// [options] — модель и язык транскрибации.
  ///
  /// Контракт ошибок одинаков для всех провайдеров (нормализованные
  /// исключения из lib/core/error/app_exception.dart):
  /// - [AuthException] — невалидный ключ (HTTP 401 или эквивалент);
  /// - [NetworkException] — сетевые ошибки, таймауты, прочие HTTP-ошибки;
  /// - [RateLimitException] — превышен лимит запросов / сервис временно
  ///   недоступен (HTTP 429/503 или эквивалент), содержит `retryAfterSeconds`;
  /// - [InternalException] — не удалось разобрать ответ провайдера.
  Future<TranscriptionResult> transcribeChunk({
    required List<int> bytes,
    required String filename,
    required String apiKey,
    TranscriptionOptions options,
  });

  /// Политика конкурентности провайдера: сколько чанков можно обрабатывать
  /// параллельно при данном количестве живых ключей [aliveKeyCount].
  ///
  /// Это единственное место, знающее политику конкурентности конкретного
  /// провайдера (например, Groq — «поток на ключ»: `clamp(1, kMaxConcurrentChunks)`,
  /// будущий Deepgram — иной режим). Контроллер и пул вызывают этот метод,
  /// не зная деталей политики.
  int concurrencyFor(int aliveKeyCount);

  /// Идентификатор провайдера — используется для выбора пула ключей по
  /// `options.model.provider` в будущих фазах (мульти-провайдерный выбор).
  TranscriptionProviderId get id;
}
