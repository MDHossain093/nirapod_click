import 'package:flutter_test/flutter_test.dart';
import 'package:nirapod_click/models/risk_result.dart';
import 'package:nirapod_click/services/risk_engine.dart';

void main() {
  final engine = RiskEngine();

  group('RiskEngine.analyzeMessage', () {
    test('obvious scam triggers critical verdict', () {
      // Multi-vector: URL + credential + urgency + payment brand.
      const msg = 'URGENT! Your bKash account has been locked. '
          'Verify your password immediately at http://bkash-verify.tk/login '
          'or you will lose all money.';

      final r = engine.analyzeMessage(msg);

      expect(r.level, RiskLevel.critical,
          reason: 'multi-vector + combo bonuses push the score into critical');
      expect(r.score, greaterThanOrEqualTo(80),
          reason: 'critical threshold is 80');
      expect(r.score, lessThanOrEqualTo(100),
          reason: 'score must clamp at the 0..100 ceiling');
      expect(r.category, 'Credential Theft',
          reason: 'credential theft outranks the other categories');
      expect(r.reasons, isNotEmpty);
      expect(
        r.reasons,
        contains('Requests sensitive authentication information'),
      );
      expect(r.confidence, greaterThan(0.6));
      expect(r.usedAi, isFalse);
    });

    test('job scam lands in medium tier with payment category', () {
      // "part-time" (hyphenated) bypasses the literal "part time job" keyword,
      // but the message still fires payment + impersonation via "bKash".
      const msg = 'Easy part-time job! Work 30 minutes a day and earn 5000 BDT '
          'daily. Send 500 taka registration fee to bKash 01712345678 to start '
          'tomorrow.';

      final r = engine.analyzeMessage(msg);

      expect(r.level, RiskLevel.medium,
          reason: '25 (payment) + 15 (impersonation) = 40 -> medium');
      expect(r.score, inInclusiveRange(35, 59));
      expect(r.category, 'Payment Scam');
      expect(
        r.reasons.any((reason) => reason.toLowerCase().contains('payment')),
        isTrue,
      );
      expect(
        r.reasons.any((reason) =>
            reason.toLowerCase().contains('bangladesh phone')),
        isTrue,
        reason: 'BD-phone signal should still fire even without score weight',
      );
      expect(
        r.reasons.any((reason) => reason.toLowerCase().contains('imperson')),
        isTrue,
      );
    });

    test('normal message stays safe', () {
      const msg = 'Hi Mom, just letting you know I arrived safely. '
          'See you at dinner tomorrow.';

      final r = engine.analyzeMessage(msg);

      expect(r.score, 0);
      expect(r.level, RiskLevel.safe);
      expect(r.category, 'General');
      expect(r.reasons, isEmpty);
      expect(r.confidence, 0.5,
          reason: 'no findings -> base confidence only');
      expect(r.usedAi, isFalse);
    });

    test('Bangladesh phone plus prize claim lands in low tier', () {
      const msg = 'Congratulations! You have won a free gift. '
          'Please contact 01712345678 to claim your prize.';

      final r = engine.analyzeMessage(msg);

      expect(r.level, RiskLevel.low);
      expect(r.score, inInclusiveRange(15, 34));
      expect(
        r.reasons.any((s) => s.toLowerCase().contains('bangladesh phone')),
        isTrue,
        reason: 'BD-phone signal must fire',
      );
      expect(
        r.reasons.any((s) =>
            s.toLowerCase().contains('prize') ||
            s.toLowerCase().contains('winning')),
        isTrue,
        reason: 'prize/winning signal must fire',
      );
      expect(r.category, 'Prize Scam');
      expect(r.usedAi, isFalse);
    });
  });
}
