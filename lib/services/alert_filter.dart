import 'checker_repository.dart';

/// Threshold above which a scan becomes a "critical" alert.
///
/// Mirrors the bucket boundary in `risk_engine.dart`, `url_risk_engine.dart`,
/// `phone_risk_engine.dart`, and the screenshot analyzer — `>= 80` is
/// labeled `critical` everywhere in the app. Using the same value here
/// means an alert-eligible scan is exactly one whose displayed level is
/// `critical`, which keeps the rule intuitive ("an alert = a critical scan
/// we're confident about").
const int kAlertScoreThreshold = 80;

/// Minimum confidence (0..1) for a scan to count as an alert.
///
/// Below this we don't trust the verdict enough to escalate — e.g. a
/// `score = 90` message with `confidence = 0.5` may be a single heuristic
/// tripping hard, not a real scam.
const double kAlertConfidenceThreshold = 0.8;

/// Pure predicate: does this scan qualify as a safety alert?
///
/// Rule (locked-in product spec):
///   `result.score >= 80 AND result.confidence >= 0.80`
///
/// Phone scans intentionally carry `confidence = 1.0` in
/// `PhoneRiskResultAdapter.toRiskResult()` so deterministic phone verdicts
/// pass the gate — see that file for the rationale. The rule itself does
/// not branch on scan type; the adapter sets the right confidence upstream.
bool isAlert(HistoryEntry entry) {
  final r = entry.result;
  if (r.score < kAlertScoreThreshold) return false;
  if (r.confidence < kAlertConfidenceThreshold) return false;
  return true;
}
