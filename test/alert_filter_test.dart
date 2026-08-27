import 'package:flutter_test/flutter_test.dart';
import 'package:nirapod_click/models/risk_result.dart';
import 'package:nirapod_click/services/alert_filter.dart';
import 'package:nirapod_click/services/checker_repository.dart';

HistoryEntry _entry({
  required int score,
  required double confidence,
  ScanType type = ScanType.message,
}) {
  return HistoryEntry(
    checkId: 'id-$score-${confidence.toStringAsFixed(2)}-${type.name}',
    result: RiskResult(
      score: score,
      level: score >= 80
          ? RiskLevel.critical
          : score >= 60
              ? RiskLevel.high
              : score >= 35
                  ? RiskLevel.medium
                  : score >= 15
                      ? RiskLevel.low
                      : RiskLevel.safe,
      category: 'Test',
      confidence: confidence,
      reasons: const ['reason'],
      recommendations: const [],
      usedAi: false,
      aiWasUnavailable: false,
    ),
    originalText: 'sample',
    createdAt: null,
    type: type,
  );
}

void main() {
  group('isAlert', () {
    test('score below 80 is rejected regardless of confidence', () {
      expect(isAlert(_entry(score: 79, confidence: 1.0)), isFalse);
      expect(isAlert(_entry(score: 0, confidence: 1.0)), isFalse);
      expect(isAlert(_entry(score: 50, confidence: 1.0)), isFalse);
    });

    test('score >= 80 with confidence below 0.8 is rejected', () {
      expect(isAlert(_entry(score: 90, confidence: 0.79)), isFalse);
      expect(isAlert(_entry(score: 100, confidence: 0.0)), isFalse);
    });

    test('boundary score=80 with confidence=0.80 is accepted (>=)', () {
      expect(isAlert(_entry(score: 80, confidence: 0.80)), isTrue);
    });

    test('boundary score=80 with confidence=0.79 is rejected', () {
      expect(isAlert(_entry(score: 80, confidence: 0.79)), isFalse);
    });

    test('boundary score=79 with confidence=1.0 is rejected', () {
      expect(isAlert(_entry(score: 79, confidence: 1.0)), isFalse);
    });

    test('high-score high-confidence alert accepted', () {
      expect(isAlert(_entry(score: 95, confidence: 0.95)), isTrue);
    });

    test('scan type does not affect the rule', () {
      // Phone: deterministic, confidence set to 1.0 by the adapter.
      final phone = _entry(score: 85, confidence: 1.0, type: ScanType.phone);
      expect(isAlert(phone), isTrue);

      // URL: same score, same confidence → also an alert.
      final url = _entry(score: 85, confidence: 1.0, type: ScanType.url);
      expect(isAlert(url), isTrue);

      // Screenshot AI-fallback path: aiWasUnavailable flag is irrelevant
      // to the rule itself — confidence is the gate.
      final screenshot = _entry(
        score: 88,
        confidence: 0.92,
        type: ScanType.screenshot,
      );
      expect(isAlert(screenshot), isTrue);
    });

    test('AI-fallback screenshot below confidence threshold is rejected', () {
      // A scan with a high score but low AI confidence should NOT be
      // promoted to an alert — that's exactly what the gate guards
      // against (a single heuristic tripping hard).
      final lowConf = _entry(
        score: 92,
        confidence: 0.5,
        type: ScanType.screenshot,
      );
      expect(isAlert(lowConf), isFalse);
    });
  });
}
