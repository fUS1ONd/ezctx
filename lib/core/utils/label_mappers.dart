import '../../features/transcription/transcription_options.dart';

/// Нормализует сырой языковой код (из API-ответа или БД) в 2-буквенный
/// uppercase для отображения. Идемпотентна — безопасно вызывать повторно.
/// Возвращает '?' если код не распознан (пусто, 'unknown', не 2 буквы).
String languageLabel(String raw) {
  if (raw.isEmpty || raw == 'unknown') return '?';
  final code = raw.split('-').first;
  if (code.length != 2) return '?';
  return code.toUpperCase();
}

/// Возвращает читаемое название провайдера транскрипции.
String providerLabel(TranscriptionProviderId provider) {
  return switch (provider) {
    TranscriptionProviderId.groq => 'Groq',
    TranscriptionProviderId.deepgram => 'Deepgram',
  };
}
