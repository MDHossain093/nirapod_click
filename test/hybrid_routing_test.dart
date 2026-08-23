import 'package:flutter_test/flutter_test.dart';
import 'package:nirapod_click/services/risk_engine.dart';

/// Sanity checks for the "is this message confident enough to skip
/// Gemini?" gate. The actual network call is covered by
/// `test/gemini_live_test.dart` (live) and `test/ai_service_test.dart`
/// (mocked). Here we only verify the *local* side of the routing
/// decision so that [HybridAnalyzer] sends the right messages to Gemini.
void main() {
  final engine = RiskEngine();

  group('HybridAnalyzer routing gate (rule-engine side)', () {
    test(
      'vague "verification" message → confidence < 0.80 → AI path',
      () {
        const msg = 'Your account needs verification. '
            'Please visit our website to complete the process.';

        final r = engine.analyzeMessage(msg);

        expect(r.score, 0,
            reason: 'no keyword matches → zero score');
        expect(r.confidence, lessThan(0.80),
            reason: 'no findings → base 0.50 → routes to Gemini');
        expect(r.usedAi, isFalse,
            reason: 'the engine itself never sets usedAi=true');
      },
    );

    test(
      'obvious scam → confidence >= 0.80 → local path only',
      () {
        const msg = 'Congratulations! You won 50,000 BDT. '
            'Send 500 BDT registration fee and share your OTP '
            'immediately.';

        final r = engine.analyzeMessage(msg);

        expect(r.score, greaterThanOrEqualTo(80));
        expect(r.confidence, greaterThanOrEqualTo(0.80),
            reason: 'multi-vector + combos → skip Gemini');
        expect(r.usedAi, isFalse);
      },
    );

    test(
      'plain chat message → confidence 0.50 → AI path',
      () {
        const msg = 'Hi Mom, just letting you know I arrived safely.';

        final r = engine.analyzeMessage(msg);

        expect(r.score, 0);
        expect(r.confidence, 0.50);
        expect(r.usedAi, isFalse);
      },
    );
  });
}
