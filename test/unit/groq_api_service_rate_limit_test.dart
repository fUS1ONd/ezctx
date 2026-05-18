import 'package:flutter_test/flutter_test.dart';

// ignore: unused_import
import 'package:ezctx/features/transcription/groq_api_service.dart';

void main() {
  group('parseRetryAfterFromHeaders', () {
    test('_parseRetryAfter возвращает секунды из retry-after', () {
      fail('RED — реализация ещё не написана');
    });

    test("_parseDurationString корректно парсит '2m59.56s' → 179", () {
      fail('RED — реализация ещё не написана');
    });

    test('fallback 60 если заголовки отсутствуют', () {
      fail('RED — реализация ещё не написана');
    });
  });
}
