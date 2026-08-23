import 'package:flutter_test/flutter_test.dart';
import 'package:nirapod_click/models/phone_risk_result.dart';
import 'package:nirapod_click/services/phone_risk_engine.dart';

void main() {
  final engine = PhoneRiskEngine();

  group('PhoneRiskEngine.analyze — normalization', () {
    test('strips spaces, dashes, and parens', () {
      final r = engine.analyze('01712 - (345) 678');
      expect(r.phoneNumber, '01712345678');
      expect(r.isValid, isTrue);
    });

    test('strips +88 country prefix', () {
      final r = engine.analyze('+8801712345678');
      expect(r.phoneNumber, '01712345678');
      expect(r.isValid, isTrue);
    });

    test('strips 88 country prefix when length is 13', () {
      final r = engine.analyze('8801712345678');
      expect(r.phoneNumber, '01712345678');
      expect(r.isValid, isTrue);
    });
  });

  group('PhoneRiskEngine.analyze — validation', () {
    test('valid BD mobile number is valid', () {
      final r = engine.analyze('01712345678');
      expect(r.isValid, isTrue);
      expect(r.operator, 'Grameenphone');
      expect(r.score, 0);
      expect(r.level, PhoneRiskLevel.safe);
    });

    test('too-short input is invalid', () {
      final r = engine.analyze('12345');
      expect(r.isValid, isFalse);
      expect(r.reasons, contains(
        'This does not appear to be a valid Bangladesh mobile number.',
      ));
      expect(r.score, 0);
    });

    test('foreign number is invalid', () {
      final r = engine.analyze('+14155551234');
      expect(r.isValid, isFalse);
    });

    test('non-mobile 02 number is invalid (mobile-only for v1)', () {
      final r = engine.analyze('0212345678');
      expect(r.isValid, isFalse);
    });

    test('empty input is invalid', () {
      final r = engine.analyze('');
      expect(r.isValid, isFalse);
    });
  });

  group('PhoneRiskEngine.analyze — operator lookup', () {
    test('Grameenphone covers 013 and 017', () {
      expect(engine.analyze('01312345678').operator, 'Grameenphone');
      expect(engine.analyze('01712345678').operator, 'Grameenphone');
    });

    test('Banglalink covers 014 and 019', () {
      expect(engine.analyze('01412345678').operator, 'Banglalink');
      expect(engine.analyze('01912345678').operator, 'Banglalink');
    });

    test('Robi is 018, Airtel is 016, Teletalk is 015', () {
      expect(engine.analyze('01812345678').operator, 'Robi');
      expect(engine.analyze('01612345678').operator, 'Airtel');
      expect(engine.analyze('01512345678').operator, 'Teletalk');
    });
  });

  group('PhoneRiskEngine.analyze — scoring', () {
    test('1 report adds +20 and a single reason', () {
      final r = engine.analyze(
        '01712345678',
        reportCount: 1,
      );
      expect(r.score, 20);
      expect(r.level, PhoneRiskLevel.low);
      expect(r.reasons, contains('This number has been reported by users.'));
    });

    test('3 reports add +20 + +15 = 35 → medium', () {
      final r = engine.analyze(
        '01712345678',
        reportCount: 3,
      );
      expect(r.score, 35);
      expect(r.level, PhoneRiskLevel.medium);
      expect(r.reasons, contains('Multiple users have reported this number.'));
    });

    test('10 reports add +20 + +15 + +20 = 55 → medium', () {
      final r = engine.analyze(
        '01712345678',
        reportCount: 10,
      );
      expect(r.score, 55);
      expect(r.level, PhoneRiskLevel.medium);
      expect(r.reasons, contains('This number has received many reports.'));
    });

    test('otp report alone jumps straight to high', () {
      final r = engine.analyze(
        '01712345678',
        reportCount: 1,
        reportTypes: ['otp'],
      );
      // 1 report (+20) + otp (+25) = 45
      expect(r.score, 45);
      expect(r.level, PhoneRiskLevel.medium);
      expect(
        r.reasons,
        contains(
          'Users have reported requests for OTP or verification codes.',
        ),
      );
    });

    test('scam + payment + otp caps at 100', () {
      final r = engine.analyze(
        '01712345678',
        reportCount: 10,
        reportTypes: ['scam', 'payment', 'otp', 'job'],
      );
      // 20 + 15 + 20 + 20 + 20 + 25 + 15 = 135 → clamp to 100
      expect(r.score, 100);
      expect(r.level, PhoneRiskLevel.critical);
    });

    test('no reports and unknown types stays safe', () {
      final r = engine.analyze(
        '01712345678',
        reportCount: 0,
        reportTypes: [],
      );
      expect(r.score, 0);
      expect(r.level, PhoneRiskLevel.safe);
      expect(r.reasons, isEmpty);
    });
  });

  group('PhoneRiskEngine.analyze — recommendations', () {
    test('safe gives the "no reports found" advisory', () {
      final r = engine.analyze('01712345678');
      expect(r.recommendations.first,
          'No suspicious reports were found.');
    });

    test('critical includes the OTP/money block', () {
      final r = engine.analyze(
        '01712345678',
        reportCount: 50,
        reportTypes: ['scam', 'payment', 'otp'],
      );
      expect(r.recommendations, contains(
        'Do not send money to this number.',
      ));
      expect(r.recommendations, contains(
        'Do not share OTP, PIN, or passwords.',
      ));
    });
  });

  group('PhoneRiskEngine.analyze — invalid passthrough', () {
    test('invalid number still reports the report count', () {
      final r = engine.analyze(
        '12345',
        reportCount: 7,
      );
      expect(r.isValid, isFalse);
      expect(r.reportCount, 7,
          reason: 'reportCount must pass through unchanged even on '
              'invalid numbers so the UI can render the count');
      expect(r.score, 0);
    });
  });
}
