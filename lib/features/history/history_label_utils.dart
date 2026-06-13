// Чистые функции нормализации лейблов истории (план 04-01).
// Никаких зависимостей от Flutter — только dart:core. Это чисто
// отображательный слой: сырое значение language/provider НЕ меняется
// нигде в репозитории (D-04/D-06), функции применяются только при рендере.

/// Нормализует ISO 639-1 или расширенный языковой тег к двухбуквенному
/// UPPERCASE-коду. Примеры: 'ru' → 'RU', 'en-US' → 'EN' (берётся часть до
/// дефиса), 'auto' → 'AUTO', '' → '—'.
String languageLabel(String raw) {
  if (raw.isEmpty) return '—';
  return raw.split('-').first.toUpperCase();
}

/// Возвращает читаемое имя провайдера транскрибации.
/// Известные провайдеры маппятся явно: 'groq' → 'Groq', 'deepgram' →
/// 'Deepgram'. Неизвестный провайдер — fallback с капитализацией первой
/// буквы (например, 'whisper' → 'Whisper'). Пустая строка → '—'.
String providerLabel(String raw) {
  if (raw.isEmpty) return '—';
  const known = {
    'groq': 'Groq',
    'deepgram': 'Deepgram',
  };
  return known[raw.toLowerCase()] ?? raw[0].toUpperCase() + raw.substring(1);
}
