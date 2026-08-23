// Tests for ScreenshotAnalyzer.
//
// We exercise the pure-Dart analyzer (no ML Kit, no Flutter) so we can
// confirm the combination logic between the message rule engine and
// the URL rule engine without needing a real screenshot.

import 'package:flutter_test/flutter_test.dart';
import 'package:nirapod_click/services/screenshot_analyzer.dart';

void main() {
  group('ScreenshotAnalyzer.analyze', () {
    final analyzer = ScreenshotAnalyzer();

    test('clean OCR text is classified safe with no findings', () {
      const text = 'Hi, are we still on for lunch tomorrow at noon? '
          'I will bring the documents.';

      final result = analyzer.analyze(text);

      expect(result.urlResults, isEmpty);
      expect(result.score, lessThan(15));
      expect(result.reasons, isEmpty);
      expect(result.category, isNotEmpty);
    });

    test('classic OTP + payment + prize text escalates to high/critical', () {
      const text = 'Congratulations! You won 50,000 taka. To claim your '
          'prize please send 500 taka processing fee to bKash 01712345678 '
          'and share the OTP 4521 we just sent you. Act now, offer ends '
          'in 10 minutes!';

      final result = analyzer.analyze(text);

      expect(result.score, greaterThanOrEqualTo(60),
          reason: 'OTP + payment + prize should push the message score '
              'into the high/critical band');
      expect(result.reasons, isNotEmpty);
    });

    test('embedded phishing URL is surfaced and raises the verdict', () {
      const text = 'Your Nagad account will be suspended. Verify now: '
          'http://bit.ly/nagad-verify-bd or call 01812345678';

      final result = analyzer.analyze(text);

      expect(result.urlResults, isNotEmpty);
      expect(result.urlResults.first.url,
          'http://bit.ly/nagad-verify-bd');

      final urlScore = result.urlResults.first.score;
      expect(urlScore, greaterThanOrEqualTo(15));

      expect(
        result.score,
        greaterThanOrEqualTo(result.messageResult.score),
      );
      expect(
        result.reasons.any((r) => r.startsWith('Link:')),
        isTrue,
        reason: 'URL reasons should be surfaced in the combined '
            '`reasons` list with a "Link: " prefix',
      );
    });

    test('message-only and URL-only risks are picked up independently', () {
      final msgOnly = analyzer.analyze(
        'You won a prize. Send your OTP 9999 to claim now.',
      );
      final urlOnly = analyzer.analyze(
        'Please review: http://bit.ly/free-netflix-2024',
      );

      expect(msgOnly.urlResults, isEmpty);
      expect(msgOnly.score, greaterThanOrEqualTo(15),
          reason: 'OTP-request alone should score above the safe cap');

      expect(urlOnly.urlResults, isNotEmpty);
      expect(urlOnly.score, greaterThanOrEqualTo(15),
          reason: 'Shortener + brand-impersonation link alone should '
              'already be risky');

      expect(msgOnly.reasons, isNot(equals(urlOnly.reasons)));
    });

    test('weighted average uses 0.65 / 0.35 split', () {
      // Both engines score at least 15: URL is a shortener, message
      // contains an OTP-request.
      const text = 'Send your OTP 9999 to claim. Verify: '
          'http://bit.ly/free-netflix-2024';

      final result = analyzer.analyze(text);

      expect(result.urlResults, isNotEmpty);
      final msg = result.messageResult.score;
      final urlMax = result.urlResults
          .map((u) => u.score)
          .reduce((a, b) => a > b ? a : b);

      final expected =
          (msg * 0.65 + urlMax * 0.35).round().clamp(0, 100);
      expect(result.score, expected,
          reason: 'Combined score should be the weighted average of '
              'message (0.65) and max-URL (0.35), clamped to 0..100');
    });

    test('blank text produces a zero-score result with no findings', () {
      final blankResult = analyzer.analyze('   \n  \t  ');

      expect(blankResult.score, 0);
      expect(blankResult.urlResults, isEmpty);
      expect(blankResult.reasons, isEmpty);

      final emptyResult = analyzer.analyze('');
      expect(emptyResult.score, 0);
      expect(emptyResult.urlResults, isEmpty);
    });

    test('category comes from whichever engine scores higher', () {
      const urlHeavy = 'FYI: http://bit.ly/free-netflix-2024';
      final urlResult = analyzer.analyze(urlHeavy);

      expect(urlResult.urlResults, isNotEmpty);
      expect(urlResult.score, greaterThanOrEqualTo(15));

      final urlCategory = urlResult.urlResults.first.category;
      expect(urlResult.category, urlCategory,
          reason: 'When the URL engine scores higher than the message '
              'engine, the URL category should be used for the combined '
              'verdict');
    });
  });
}
