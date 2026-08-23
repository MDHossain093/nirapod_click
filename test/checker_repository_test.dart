import 'package:flutter_test/flutter_test.dart';
import 'package:nirapod_click/models/risk_result.dart';
import 'package:nirapod_click/services/checker_repository.dart';

/// Pure-Dart tests for [serializeCheck] / [deserializeCheck] / [parseScanType].
/// The Firestore I/O surface (`save`, `watchRecent`, `clearAll`) is exercised
/// indirectly by the integration tests in `firestore.rules.test.js`.
void main() {
  group('serializeCheck', () {
    const sample = RiskResult(
      level: RiskLevel.high,
      score: 78,
      confidence: 0.83,
      reasons: ['Asks for OTP', 'Mentions bKash', 'Uses urgent language'],
      recommendations: ['Do not click', 'Report to 999'],
      category: 'Credential Theft',
      usedAi: false,
    );

    test('defaults type to "message" when not provided', () {
      final payload = serializeCheck(sample, 'hello there');
      expect(payload['type'], 'message',
          reason: 'legacy callers must keep producing message-type docs');
      expect(payload['level'], 'high');
      expect(payload['score'], 78);
      expect(payload['confidence'], 0.83);
      expect(payload['category'], 'Credential Theft');
      expect(payload['reasons'], hasLength(3));
    });

    test('honors explicit ScanType.url', () {
      final payload = serializeCheck(
        sample,
        'http://bkash-verify.tk/login',
        type: ScanType.url,
      );
      expect(payload['type'], 'url');
    });

    test('honors ScanType.screenshot and ScanType.phone', () {
      final urlPayload = serializeCheck(
        sample,
        'preview text',
        type: ScanType.screenshot,
      );
      final phonePayload = serializeCheck(
        sample,
        '01712345678',
        type: ScanType.phone,
      );
      expect(urlPayload['type'], 'screenshot');
      expect(phonePayload['type'], 'phone');
    });

    test('clamps over-long originalText to maxOriginalText', () {
      final payload =
          serializeCheck(sample, 'x' * (CheckLimits.maxOriginalText + 250));
      expect((payload['originalText'] as String).length,
          CheckLimits.maxOriginalText);
    });

    test('clamps over-long reasons to maxReasons x maxReasonLength', () {
      final manyReasons = List<String>.generate(
        CheckLimits.maxReasons + 10,
        (_) => 'r' * (CheckLimits.maxReasonLength + 50),
      );
      final payload = serializeCheck(
        RiskResult(
          level: RiskLevel.medium,
          score: 40,
          confidence: 0.5,
          reasons: manyReasons,
          recommendations: const [],
          category: 'General',
        ),
        'hello',
      );
      final reasons = payload['reasons'] as List;
      expect(reasons.length, CheckLimits.maxReasons);
      for (final r in reasons) {
        expect((r as String).length, CheckLimits.maxReasonLength);
      }
    });

    test('clamps score to 0..100', () {
      final tooHigh = serializeCheck(
        RiskResult(
          level: RiskLevel.critical,
          score: 250,
          confidence: 0.9,
          reasons: const [],
          recommendations: const [],
          category: 'Test',
        ),
        'oops',
      );
      expect(tooHigh['score'], 100);

      final tooLow = serializeCheck(
        RiskResult(
          level: RiskLevel.safe,
          score: -42,
          confidence: 0.0,
          reasons: const [],
          recommendations: const [],
          category: 'Test',
        ),
        'oops',
      );
      expect(tooLow['score'], 0);
    });

    test('clamps confidence to 0.0..1.0', () {
      final overConfident = serializeCheck(
        RiskResult(
          level: RiskLevel.high,
          score: 60,
          confidence: 1.7,
          reasons: const [],
          recommendations: const [],
          category: 'Test',
        ),
        'x',
      );
      expect(overConfident['confidence'], 1.0);
    });
  });

  group('deserializeCheck', () {
    test('round-trips a freshly serialized payload', () {
      const original = RiskResult(
        level: RiskLevel.medium,
        score: 42,
        confidence: 0.6,
        reasons: ['Phishing link'],
        recommendations: ['Do not click'],
        category: 'Phishing',
      );
      final payload = serializeCheck(original, 'click here');
      final restored = deserializeCheck(payload);

      expect(restored.level, original.level);
      expect(restored.score, original.score);
      expect(restored.confidence, original.confidence);
      expect(restored.reasons, original.reasons);
      expect(restored.category, original.category);
    });

    test('falls back to RiskLevel.low on unknown level', () {
      final r = deserializeCheck({
        'score': 10,
        'level': 'meteoric',
        'category': 'Test',
        'confidence': 0.5,
        'reasons': <String>[],
      });
      expect(r.level, RiskLevel.low);
    });
  });

  group('parseScanType', () {
    test('maps known wire names to the enum', () {
      expect(parseScanType('message'), ScanType.message);
      expect(parseScanType('url'), ScanType.url);
      expect(parseScanType('screenshot'), ScanType.screenshot);
      expect(parseScanType('phone'), ScanType.phone);
    });

    test('falls back to message for missing / unknown values', () {
      expect(parseScanType(null), ScanType.message);
      expect(parseScanType(42), ScanType.message);
      expect(parseScanType('email'), ScanType.message);
    });
  });
}