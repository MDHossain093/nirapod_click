/// Outcome of analysing one message.
///
/// Pure data class — no Flutter, no Firebase. The rule engine
/// ([RiskEngine] in `risk_engine.dart`) is the only thing that produces a
/// [RiskResult] right now; later the Gemini Cloud Function may overwrite
/// the verdict for ambiguous messages.
library;

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

  const RiskResult({
    required this.level,
    required this.score,
    required this.confidence,
    required this.reasons,
    required this.recommendations,
    required this.category,
    this.usedAi = false,
  });
}
