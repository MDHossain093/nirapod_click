import '../models/risk_result.dart';
import '../models/url_risk_result.dart';
import 'risk_engine.dart';
import 'url_risk_engine.dart';

/// Combined verdict from running both the message rule engine and
/// the URL rule engine over the text extracted from a screenshot.
///
/// Score combination is a weighted average (0.65 × message + 0.35 ×
/// highest URL score) — the message side carries more weight because
/// chat-style scams lean on linguistic signals (OTP request, prize
/// wording, urgency) more than on embedded URLs.
class ScreenshotAnalysis {
  final RiskResult messageResult;
  final List<UrlRiskResult> urlResults;

  final int score;
  final String category;
  final List<String> reasons;
  final List<String> recommendations;

  /// `true` when this combined verdict was produced by the local
  /// [ScreenshotAnalyzer] because the AI fallback path failed. The UI
  /// surfaces this as a non-blocking "AI analysis unavailable" banner.
  final bool aiWasUnavailable;

  const ScreenshotAnalysis({
    required this.messageResult,
    required this.urlResults,
    required this.score,
    required this.category,
    required this.reasons,
    required this.recommendations,
    this.aiWasUnavailable = false,
  });
}

class ScreenshotAnalyzer {
  final RiskEngine _messageEngine = RiskEngine();
  final UrlRiskEngine _urlEngine = UrlRiskEngine();

  /// Runs the message engine over the full text **and** the URL
  /// engine over every embedded link, then merges the two streams
  /// into one [ScreenshotAnalysis].
  ///
  /// Combination rules:
  ///   * **Score** = round(message × 0.65 + max(url) × 0.35),
  ///     clamped to 0..100.
  ///   * **Category** = URL engine's category if its score beats the
  ///     message engine's score; otherwise the message engine's.
  ///   * **Reasons** = message reasons + every URL reason prefixed
  ///     with `"Link: "` (de-duplicated).
  ///   * **Recommendations** = message engine's recommendations
  ///     (de-duplicated).
  ScreenshotAnalysis analyze(String text) {
    final messageResult = _messageEngine.analyzeMessage(text);

    final urls = _extractUrls(text);

    final urlResults = urls
        .map((url) => _urlEngine.analyze(url))
        .toList();

    int finalScore = messageResult.score;

    final reasons = <String>[
      ...messageResult.reasons,
    ];

    final recommendations = <String>[
      ...messageResult.recommendations,
    ];

    String category = messageResult.category;

    // Add URL risk to the overall score.
    if (urlResults.isNotEmpty) {
      final highestUrlRisk = urlResults
          .map((result) => result.score)
          .reduce((a, b) => a > b ? a : b);

      finalScore = ((finalScore * 0.65) +
              (highestUrlRisk * 0.35))
          .round();

      finalScore = finalScore.clamp(0, 100);

      for (final result in urlResults) {
        reasons.addAll(
          result.reasons.map(
            (reason) => 'Link: $reason',
          ),
        );
      }

      if (highestUrlRisk > messageResult.score) {
        category = urlResults
            .reduce(
              (a, b) =>
                  a.score > b.score ? a : b,
            )
            .category;
      }
    }

    // Remove duplicate reasons.
    final uniqueReasons =
        reasons.toSet().toList();

    final uniqueRecommendations =
        recommendations.toSet().toList();

    return ScreenshotAnalysis(
      messageResult: messageResult,
      urlResults: urlResults,
      score: finalScore,
      category: category,
      reasons: uniqueReasons,
      recommendations: uniqueRecommendations,
    );
  }

  /// Extracts every URL-looking substring from [text].
  ///
  /// Matches:
  ///   * `http://...` / `https://...`
  ///   * `www.example...`
  ///
  /// Until the next whitespace.
  List<String> _extractUrls(String text) {
    final regex = RegExp(
      r'((https?:\/\/|www\.)[^\s]+)',
      caseSensitive: false,
    );

    return regex
        .allMatches(text)
        .map((match) => match.group(0)!)
        .toList();
  }
}

