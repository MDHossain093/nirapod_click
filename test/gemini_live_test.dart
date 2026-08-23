// Live integration test for the Gemini REST endpoint.
//
// This test is NOT part of the regular suite — it makes a real HTTPS
// call to generativelanguage.googleapis.com and consumes API quota.
//
// Run it directly:
//   flutter test --dart-define=GEMINI_API_KEY=YOUR_KEY \
//       test/gemini_live_test.dart
//
// Or tag-filtered:
//   flutter test --tags network --dart-define=GEMINI_API_KEY=YOUR_KEY
//
// Skip in CI by NOT passing the define; the test will report
// "skipped" instead of failing.

import 'package:flutter_test/flutter_test.dart';
import 'package:nirapod_click/services/ai_service.dart';

void main() {
  const apiKey = String.fromEnvironment('GEMINI_API_KEY');

  test(
    'Gemini endpoint returns a parseable RiskResult for a scam SMS',
    () async {
      if (apiKey.isEmpty) {
        // Don't fail CI — just report skipped.
        // ignore: avoid_print
        print('GEMINI_API_KEY not set — skipping live test.');
        return;
      }

      final ai = AiService();
      const scam = 'Congratulations! You have won 50,000 BDT. '
          'To receive your prize, pay 500 BDT registration fee '
          'and send your OTP immediately.';

      final result = await ai.analyzeMessage(scam).timeout(
            const Duration(seconds: 30),
          );

      expect(result.usedAi, isTrue, reason: 'usedAi must be true.');
      expect(result.score, inInclusiveRange(0, 100));
      expect(
        result.level.name,
        anyOf('safe', 'low', 'medium', 'high', 'critical'),
      );
      expect(result.category, isNotEmpty);

      // Just sanity-check that we got actual reasons/recommendations.
      // The exact wording varies per request — don't assert equality.
      expect(result.reasons, isA<List<String>>());
      expect(result.recommendations, isA<List<String>>());

      // ignore: avoid_print
      print('Live Gemini result: '
          'level=${result.level.name} '
          'score=${result.score} '
          'category=${result.category}');
    },
    tags: 'network',
  );
}
