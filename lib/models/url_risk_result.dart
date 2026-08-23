/// Outcome of analysing one URL.
///
/// Pure data class — no Flutter, no Firebase. Produced by
/// [UrlRiskEngine] in `services/url_risk_engine.dart`; on low local
/// confidence the [UrlHybridAnalyzer] may overwrite the verdict with
/// Gemini's reply.
///
/// `url` is the raw string the user submitted (after trimming), and
/// `usedAi` flags whether Gemini produced the final verdict.
library;

enum UrlRiskLevel {
  safe,
  low,
  medium,
  high,
  critical,
}

class UrlRiskResult {
  final UrlRiskLevel level;
  final int score;
  final double confidence;
  final String category;
  final String url;
  final List<String> reasons;
  final List<String> recommendations;
  final bool usedAi;

  /// `true` when this verdict was produced by [UrlRiskEngine] because
  /// the AI fallback path failed. The UI surfaces this as a non-blocking
  /// "AI analysis unavailable" banner.
  final bool aiWasUnavailable;

  const UrlRiskResult({
    required this.level,
    required this.score,
    required this.confidence,
    required this.category,
    required this.url,
    required this.reasons,
    required this.recommendations,
    this.usedAi = false,
    this.aiWasUnavailable = false,
  });
}
