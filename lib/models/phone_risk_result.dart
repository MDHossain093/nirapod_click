/// Result model for the Phone Number Checker.
///
/// Pure-Dart, immutable. Lives next to `risk_result.dart` and
/// `url_risk_result.dart` because all three checker screens share
/// the same 5-tier verdict vocabulary (safe/low/medium/high/critical).
///
/// The level is driven by [_score] which is a 0..100 risk score
/// computed by `PhoneRiskEngine`. `reportCount` and `reportTypes`
/// are forwarded in so the UI can show "Reported 7 times (Scam: 4)"
/// once Firestore is wired in — for now they default to empty.
library;

enum PhoneRiskLevel {
  safe,
  low,
  medium,
  high,
  critical,
}

class PhoneRiskResult {
  /// The phone number as it was normalized by the engine
  /// (whitespace and dashes stripped, +88 / 88 prefix removed).
  final String phoneNumber;

  /// `false` when the input is not a valid Bangladesh mobile number.
  /// In that case the rest of the fields are zeroed out and the
  /// UI just shows the reason "Not a Bangladesh number".
  final bool isValid;

  /// Operator brand detected from the prefix
  /// (`Grameenphone`, `Banglalink`, `Robi`, `Airtel`, `Teletalk`),
  /// or `'Unknown'` if the prefix didn't match any registered brand.
  final String operator;

  /// Bucket derived from [score].
  final PhoneRiskLevel level;

  /// 0..100 risk score. Higher = riskier.
  final int score;

  /// Number of community reports for this number. `0` until
  /// Firestore is connected — the engine accepts this as a
  /// parameter so the UI layer can pass it in later without
  /// changing the model.
  final int reportCount;

  /// Human-readable reasons that pushed the score up.
  final List<String> reasons;

  /// Actionable advice the user should follow given [level].
  final List<String> recommendations;

  const PhoneRiskResult({
    required this.phoneNumber,
    required this.isValid,
    required this.operator,
    required this.level,
    required this.score,
    required this.reportCount,
    required this.reasons,
    required this.recommendations,
  });
}
