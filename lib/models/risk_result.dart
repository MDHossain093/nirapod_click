/// Outcome of analysing one message.
///
/// Pure data class - no Flutter, no Firebase. The rule engine
/// ([RiskEngine] in `risk_engine.dart`) is the only thing that produces a
/// [RiskResult] right now; later the Gemini Cloud Function may overwrite
/// the verdict for ambiguous messages.
library;

import 'url_risk_result.dart';
import 'phone_risk_result.dart';

enum RiskLevel {
  safe,
  low,
  medium,
  high,
  critical,
}

class RiskResult {
  final RiskLevel level;
  final int score;
  final double confidence;
  final List<String> reasons;
  final List<String> recommendations;
  final String category;
  final bool usedAi;

  /// `true` when this verdict was produced by the local rule engine
  /// because the AI fallback path failed (network error, missing key,
  /// Gemini returned a non-2xx, etc.). The UI shows a non-blocking
  /// warning banner when this is set so the user understands the
  /// result came from the local engine rather than Gemini.
  final bool aiWasUnavailable;

  const RiskResult({
    required this.level,
    required this.score,
    required this.confidence,
    required this.reasons,
    required this.recommendations,
    required this.category,
    this.usedAi = false,
    this.aiWasUnavailable = false,
  });
}

/// Adapter so the URL checker can save its verdict through the same
/// [RiskResult] history pipeline.
extension UrlRiskResultAdapter on UrlRiskResult {
  RiskResult toRiskResult() => RiskResult(
        level: RiskLevel.values.firstWhere(
          (l) => l.name == level.name,
          orElse: () => RiskLevel.low,
        ),
        score: score,
        confidence: confidence,
        reasons: reasons,
        recommendations: recommendations,
        category: category,
        usedAi: usedAi,
        aiWasUnavailable: aiWasUnavailable,
      );
}

/// Adapter so the Phone Number Checker can save its verdict through the
/// same [RiskResult] history pipeline.
extension PhoneRiskResultAdapter on PhoneRiskResult {
  RiskResult toRiskResult({String fallbackCategory = 'Phone Number'}) {
    return RiskResult(
      level: RiskLevel.values.firstWhere(
        (l) => l.name == level.name,
        orElse: () => RiskLevel.low,
      ),
      score: score,
      confidence: reportCount > 0
          ? (0.5 + (reportCount / 20.0)).clamp(0.0, 1.0)
          : 0.5,
      reasons: reasons,
      recommendations: recommendations,
      category: fallbackCategory,
      usedAi: false,
      // Phone verdicts never go through the AI fallback path; the
      // adapter exists only to bridge into the message-style pipeline.
      aiWasUnavailable: false,
    );
  }
}
