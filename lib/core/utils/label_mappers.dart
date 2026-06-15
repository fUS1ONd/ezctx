import '../../features/transcription/transcription_options.dart';

/// Карта полных английских названий языков (как их возвращает Groq Whisper
/// в формате verbose_json — 'russian', 'english', ...) в ISO 639-1 коды.
/// Источник — словарь LANGUAGES Whisper (99 языков) + распространённые алиасы.
/// Hawaiian/Cantonese не имеют 639-1 кода — для них отдан ISO 639-3 (haw/yue).
const Map<String, String> _whisperLanguageCodes = {
  'english': 'en',
  'chinese': 'zh',
  'german': 'de',
  'spanish': 'es',
  'russian': 'ru',
  'korean': 'ko',
  'french': 'fr',
  'japanese': 'ja',
  'portuguese': 'pt',
  'turkish': 'tr',
  'polish': 'pl',
  'catalan': 'ca',
  'dutch': 'nl',
  'arabic': 'ar',
  'swedish': 'sv',
  'italian': 'it',
  'indonesian': 'id',
  'hindi': 'hi',
  'finnish': 'fi',
  'vietnamese': 'vi',
  'hebrew': 'he',
  'ukrainian': 'uk',
  'greek': 'el',
  'malay': 'ms',
  'czech': 'cs',
  'romanian': 'ro',
  'danish': 'da',
  'hungarian': 'hu',
  'tamil': 'ta',
  'norwegian': 'no',
  'thai': 'th',
  'urdu': 'ur',
  'croatian': 'hr',
  'bulgarian': 'bg',
  'lithuanian': 'lt',
  'latin': 'la',
  'maori': 'mi',
  'malayalam': 'ml',
  'welsh': 'cy',
  'slovak': 'sk',
  'telugu': 'te',
  'persian': 'fa',
  'latvian': 'lv',
  'bengali': 'bn',
  'serbian': 'sr',
  'azerbaijani': 'az',
  'slovenian': 'sl',
  'kannada': 'kn',
  'estonian': 'et',
  'macedonian': 'mk',
  'breton': 'br',
  'basque': 'eu',
  'icelandic': 'is',
  'armenian': 'hy',
  'nepali': 'ne',
  'mongolian': 'mn',
  'bosnian': 'bs',
  'kazakh': 'kk',
  'albanian': 'sq',
  'swahili': 'sw',
  'galician': 'gl',
  'marathi': 'mr',
  'punjabi': 'pa',
  'sinhala': 'si',
  'khmer': 'km',
  'shona': 'sn',
  'yoruba': 'yo',
  'somali': 'so',
  'afrikaans': 'af',
  'occitan': 'oc',
  'georgian': 'ka',
  'belarusian': 'be',
  'tajik': 'tg',
  'sindhi': 'sd',
  'gujarati': 'gu',
  'amharic': 'am',
  'yiddish': 'yi',
  'lao': 'lo',
  'uzbek': 'uz',
  'faroese': 'fo',
  'haitian creole': 'ht',
  'pashto': 'ps',
  'turkmen': 'tk',
  'nynorsk': 'nn',
  'maltese': 'mt',
  'sanskrit': 'sa',
  'luxembourgish': 'lb',
  'myanmar': 'my',
  'tibetan': 'bo',
  'tagalog': 'tl',
  'malagasy': 'mg',
  'assamese': 'as',
  'tatar': 'tt',
  'hawaiian': 'haw',
  'lingala': 'ln',
  'hausa': 'ha',
  'bashkir': 'ba',
  'javanese': 'jw',
  'sundanese': 'su',
  'cantonese': 'yue',
  // Алиасы Whisper (TO_LANGUAGE_CODE).
  'burmese': 'my',
  'valencian': 'ca',
  'flemish': 'nl',
  'haitian': 'ht',
  'letzeburgesch': 'lb',
  'pushto': 'ps',
  'panjabi': 'pa',
  'moldavian': 'ro',
  'moldovan': 'ro',
  'sinhalese': 'si',
  'castilian': 'es',
  'mandarin': 'zh',
};

/// Нормализует сырой языковой код для отображения в короткий ISO-код
/// в UPPERCASE. Обрабатывает три формы входа:
///  • полное название языка от Groq Whisper ('russian' → 'RU');
///  • 2-буквенный ISO 639-1 код от Deepgram ('ru' → 'RU'), в т.ч. с BCP-47
///    регионом ('en-US' → 'EN');
///  • уже нормализованное значение ('RU' → 'RU'), т.е. функция идемпотентна.
/// Возвращает '?' если код не распознан (пусто, 'unknown', не 2 буквы).
String languageLabel(String raw) {
  if (raw.isEmpty || raw == 'unknown') return '?';
  // Groq Whisper отдаёт полное английское название языка — мапим в ISO 639-1.
  final mapped = _whisperLanguageCodes[raw.toLowerCase()];
  if (mapped != null) return mapped.toUpperCase();
  // Deepgram / уже-нормализованные значения: 2-буквенный код (± BCP-47 регион).
  final code = raw.split('-').first;
  if (code.length != 2) return '?'; // отклоняем нераспознанные коды и названия
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
    'groq' => 'Groq',
    'deepgram' => 'Deepgram',
    _ => name,
  };
}
