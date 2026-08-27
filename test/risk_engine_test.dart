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
      // NB: avoid "free gift" — the device-bait rule now fires on that
      // phrase, which would push this into medium. We're testing the
      // minimal "prize + BD phone" combination for the low tier.
      const msg = 'Congratulations! You have won a special reward. '
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

  // ─── BD-specific ScamRule coverage ──────────────────────────────────
  //
  // Each test below exercises ONE of the 15 new categories added to
  // `defaultScam_rules.dart` after the audit. Goal: lock in that the
  // new rules trip on the canonical BD scam pattern (one signal alone
  // is enough to push the score into the high/critical tier, so the
  // scan resolves locally without hitting Gemini).

  group('BD-specific ScamRule coverage', () {
    test('kyc_update fires on KYC/NID wording', () {
      const msg = 'আপনার এনআইডি আপডেট করুন অন্যথায় অ্যাকাউন্ট বন্ধ হবে।';
      final r = engine.analyzeMessage(msg);
      expect(
        r.reasons.any((s) => s.toLowerCase().contains('kyc') ||
            s.toLowerCase().contains('nid')),
        isTrue,
        reason: 'KYC update reason must fire',
      );
      expect(r.score, greaterThanOrEqualTo(25));
    });

    test('imei_sim_block fires on SIM-block threat', () {
      const msg = 'আপনার সিম ব্লক হয়ে যাবে। এখনই যোগাযোগ করুন।';
      final r = engine.analyzeMessage(msg);
      expect(
        r.reasons.any((s) => s.toLowerCase().contains('sim') ||
            s.toLowerCase().contains('imei')),
        isTrue,
      );
      expect(r.score, greaterThanOrEqualTo(25));
    });

    test('fake_courier fires on parcel wording', () {
      const msg = 'আপনার কুরিয়ার পার্সেল এসেছে, কাস্টমস ডিউটি দিন।';
      final r = engine.analyzeMessage(msg);
      expect(
        r.reasons.any((s) => s.toLowerCase().contains('courier') ||
            s.toLowerCase().contains('parcel')),
        isTrue,
      );
    });

    test('utility_bill fires on DESCO / WASA / gas wording', () {
      const msg = 'আপনার বিদ্যুৎ বিল বকেয়া আছে, এখনই DESCO পেমেন্ট করুন।';
      final r = engine.analyzeMessage(msg);
      expect(
        r.reasons.any((s) => s.toLowerCase().contains('utility') ||
            s.toLowerCase().contains('desco') ||
            s.toLowerCase().contains('bill')),
        isTrue,
      );
    });

    test('govt_subsidy fires on subsidy wording', () {
      const msg = 'সরকারি ভর্তুকি পেতে আপনার তথ্য দিন।';
      final r = engine.analyzeMessage(msg);
      expect(
        r.reasons.any((s) => s.toLowerCase().contains('subsidy') ||
            s.toLowerCase().contains('ভর্তুকি'.toLowerCase())),
        isTrue,
      );
    });

    test('police_threat fires on arrest/warrant wording', () {
      const msg = 'আপনার বিরুদ্ধে গ্রেপ্তার ওয়ারেন্ট আছে, এখনই যোগাযোগ করুন।';
      final r = engine.analyzeMessage(msg);
      expect(
        r.reasons.any((s) => s.toLowerCase().contains('police') ||
            s.toLowerCase().contains('legal') ||
            s.toLowerCase().contains('arrest')),
        isTrue,
      );
    });

    test('family_impersonation fires on "new number from mom/dad"', () {
      const msg = 'আম্মা আমি নতুন নম্বর থেকে লিখছি, একটু টাকা পাঠাও।';
      final r = engine.analyzeMessage(msg);
      expect(
        r.reasons.any((s) => s.toLowerCase().contains('family') ||
            s.toLowerCase().contains('member')),
        isTrue,
      );
    });

    test('crypto_investment fires on bitcoin/investment wording', () {
      const msg = 'Invest in bitcoin and double in 24 hours. '
          'Guaranteed returns every week.';
      final r = engine.analyzeMessage(msg);
      expect(
        r.reasons.any((s) => s.toLowerCase().contains('crypto') ||
            s.toLowerCase().contains('investment')),
        isTrue,
      );
    });

    test('romance fires on love/bahadur wording', () {
      const msg = 'My dear bahadur, I love you. Please send money for ticket.';
      final r = engine.analyzeMessage(msg);
      expect(
        r.reasons.any((s) => s.toLowerCase().contains('romance')),
        isTrue,
      );
    });

    test('cashback_bonus fires on cashback/points wording', () {
      const msg = 'Your reward points are expiring. Claim your cashback now.';
      final r = engine.analyzeMessage(msg);
      expect(
        r.reasons.any((s) => s.toLowerCase().contains('cashback') ||
            s.toLowerCase().contains('bonus')),
        isTrue,
      );
    });

    test('freelance_job fires on data-entry/typing wording', () {
      const msg = 'ফ্রিল্যান্সিং ডাটা এন্ট্রি জব, ঘরে বসে আয় ৫০০০ টাকা।';
      final r = engine.analyzeMessage(msg);
      expect(
        r.reasons.any((s) => s.toLowerCase().contains('freelance') ||
            s.toLowerCase().contains('data entry') ||
            s.toLowerCase().contains('job')),
        isTrue,
      );
    });

    test('microcredit_loan fires on instant-loan wording', () {
      const msg = 'মাইক্রোক্রেডিট লোন, ৫ মিনিটে অনুমোদন, দ্রুত ঋণ।';
      final r = engine.analyzeMessage(msg);
      expect(
        r.reasons.any((s) => s.toLowerCase().contains('microcredit') ||
            s.toLowerCase().contains('loan') ||
            s.toLowerCase().contains('ঋণ'.toLowerCase())),
        isTrue,
      );
    });

    test('ecommerce_refund fires on Daraz/refund wording', () {
      const msg = 'Daraz রিফান্ড প্রক্রিয়া করতে আপনার তথ্য দিন।';
      final r = engine.analyzeMessage(msg);
      expect(
        r.reasons.any((s) => s.toLowerCase().contains('refund') ||
            s.toLowerCase().contains('daraz')),
        isTrue,
      );
    });

    test('device_bait fires on free-phone wording', () {
      const msg = 'ফ্রি আইফোন জিতেছেন! এখনই দাবি করুন।';
      final r = engine.analyzeMessage(msg);
      expect(
        r.reasons.any((s) => s.toLowerCase().contains('device') ||
            s.toLowerCase().contains('bait') ||
            s.toLowerCase().contains('free')),
        isTrue,
      );
    });

    test('otp_share_request fires on share-OTP-with-agent wording', () {
      const msg = 'Please share otp with our customer care agent for verification.';
      final r = engine.analyzeMessage(msg);
      expect(
        r.reasons.any((s) =>
            s.toLowerCase().contains('share your otp') ||
            s.toLowerCase().contains('otp share request')),
        isTrue,
        reason: 'otp-share-request reason must fire',
      );
    });
  });

  // ─── Confidence gate ────────────────────────────────────────────────
  //
  // Locks in the +0.20 strong-score boost. A multi-signal critical scan
  // with ≥2 reasons and ≥2 categories must cross 0.80 (the AI gate).
  // A score=70 borderline must NOT cross 0.80 (regression guard so we
  // don't accidentally call less-than-critical scans "confident" and
  // skip the AI safety net).

  group('confidence gate', () {
    test('score>=85 with >=2 reasons and >=2 categories clears the AI gate', () {
      // 25 (payment) + 30 (credential theft) + 15 (urgency) + 15 (URL)
      // + 15 (impersonation) + 15 (Payment+Credential combo)
      // + 10 (Urgency+URL combo) = 125 → clamped to 100.
      const msg = 'URGENT! Your bKash account will be suspended. '
          'Send money and share your OTP and password immediately at '
          'http://bkash-verify.tk/login to verify your account.';
      final r = engine.analyzeMessage(msg);

      expect(r.level, RiskLevel.critical);
      expect(r.score, greaterThanOrEqualTo(85));
      expect(
        r.confidence,
        greaterThanOrEqualTo(0.80),
        reason: 'multi-signal critical scan must clear the 0.80 AI gate',
      );
      expect(r.reasons.length, greaterThanOrEqualTo(2));
    });

    test('score in borderline 60-69 band stays below the AI gate', () {
      // Construct a borderline case: urgency + payment + account
      // = 15 + 25 + 20 = 60. Three reasons, three categories.
      // No combo bonuses fire (urgency+URL is the only combo
      // and there's no URL; prize+payment needs prize).
      // Confidence must stay under 0.80 — the score >= 70 boost is
      // what triggers an additional +0.10, so a score-60 scan must
      // keep going to AI.
      const msg = 'Urgent. Send money and verify your account immediately.';
      final r = engine.analyzeMessage(msg);

      expect(r.score, inInclusiveRange(60, 69),
          reason: 'constructed to sit in the borderline band');
      expect(r.confidence, lessThan(0.80),
          reason: 'borderline score band must NOT auto-pass the AI gate');
    });
  });
}
