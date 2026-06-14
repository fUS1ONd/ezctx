import '../../features/transcription/transcription_options.dart';

/// Нормализует сырой языковой код (из API-ответа или БД) в 2-буквенный
/// uppercase для отображения. Идемпотентна — безопасно вызывать повторно.
/// Возвращает '?' если код не распознан (пусто, 'unknown', не 2 буквы).
String languageLabel(String raw) {
  if (raw.isEmpty || raw == 'unknown') return '?';
  final code = raw.split('-').first;
  if (code.length != 2) return '?'; // отклоняем ISO 639-2 трёхбуквенные коды
  return code.toUpperCase();
}

/// Возвращает читаемое название провайдера транскрипции.
String providerLabel(TranscriptionProviderId provider) {
  return switch (provider) {
    TranscriptionProviderId.groq => 'Groq',
    TranscriptionProviderId.deepgram => 'Deepgram',
  };
}

/// Возвращает читаемое название провайдера по его строковому имени из БД.
/// Graceful fallback: возвращает само имя если провайдер не распознан.
String providerLabelFromName(String name) {
  return switch (name) {
    'groq'     => 'Groq',
    'deepgram' => 'Deepgram',
    _          => name,
  };
}
