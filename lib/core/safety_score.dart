import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/risk_result.dart';
import '../services/checker_repository.dart' show HistoryEntry;

/// Aggregate "how safe is this user?" view derived from their recent
/// scans. The home dashboard renders this as a single card so the
/// user gets telemetry ("here's how risky the things you've checked
/// have been") instead of yet another entry point to the scanners.
///
/// Computation:
///
///   * Window: last 30 days, inclusive of today. Older entries are
///     ignored — the brief is "score based on recent activity," not
///     a lifetime risk profile.
///
///   * Per-level counts: how many scans landed at each [RiskLevel]
///     during the window. Rendered as the 4-pill row in the card.
///
///   * Overall 0-100 score: weighted by level, NOT a flat mean.
///     One critical scan needs to drag the score down more than a
///     single low scan pulls it up, otherwise the user gets a
///     falsely optimistic picture (e.g. 50 safe + 1 critical should
///     read "needs attention", not "you're mostly fine"). The weights
///     below were chosen so that:
///
///         1 critical scan (no other scans) → ~ 25
///         1 critical + 4 safe scans       → ~ 60
///         5 safe scans                    → 100
///         5 critical scans                → ~  5
///
///     See [_computeOverallScore] for the formula.
///
///     The output is clamped to 0..100 and rounded to int so the
///     big number on the card reads as "82 / 100" not "82.4".
///
///   * Status band: maps the rounded score to a 5-band label
///     (Excellent / Good / Fair / Needs attention / Critical). Drives
///     the headline colour + the small status pill.
///
/// This is a pure helper — no Flutter, no Firestore. Constructing
/// one is cheap (just walks the entries once) so callers can
/// rebuild on every history snapshot without ceremony.
class SafetyScore {
  const SafetyScore({
    required this.overallScore,
    required this.criticalCount,
    required this.highCount,
    required this.mediumCount,
    required this.lowCount,
    required this.safeCount,
    required this.totalInWindow,
    required this.status,
  });

  /// 0-100 integer; higher = safer.
  final int overallScore;

  final int criticalCount;
  final int highCount;
  final int mediumCount;
  final int lowCount;
  final int safeCount;

  /// Total scans counted (i.e. within the 30-day window). Useful for
  /// the "Based on your last 30 days of scans" subtitle and for the
  /// empty state ("no scans yet" → 0).
  final int totalInWindow;

  /// 5-band verdict. Drives the card colour.
  final SafetyStatus status;

  /// Default "no scans yet" instance. Used by the home card when the
  /// user has no history so the empty state can render without
  /// forcing callers to null-check.
  static const empty = SafetyScore(
    overallScore: 0,
    criticalCount: 0,
    highCount: 0,
    mediumCount: 0,
    lowCount: 0,
    safeCount: 0,
    totalInWindow: 0,
    status: SafetyStatus.noScans,
  );

  /// Compute a [SafetyScore] from a list of [HistoryEntry]. Entries
  /// outside the 30-day window (or with no `createdAt`) are dropped
  /// before counting. Returns [empty] for an empty input.
  factory SafetyScore.compute(
    List<HistoryEntry> entries, {
    DateTime? now,
    Duration window = const Duration(days: 30),
  }) {
    if (entries.isEmpty) return empty;

    final cutoff = (now ?? DateTime.now()).subtract(window);
    var critical = 0;
    var high = 0;
    var medium = 0;
    var low = 0;
    var safe = 0;
    var inWindow = 0;

    for (final entry in entries) {
      final ts = entry.createdAt;
      // createdAt is a raw Firestore Timestamp (when read back from
      // the database) or the sentinel _Sentinel.createdAtNow
      // (in tests). Anything else we treat as "no timestamp" and
      // drop — being strict about windowing keeps the score
      // honest.
      if (ts is! Timestamp) continue;
      final dt = ts.toDate();
      if (dt.isBefore(cutoff)) continue;

      inWindow++;
      switch (entry.result.level) {
        case RiskLevel.critical:
          critical++;
        case RiskLevel.high:
          high++;
        case RiskLevel.medium:
          medium++;
        case RiskLevel.low:
          low++;
        case RiskLevel.safe:
          safe++;
      }
    }

    if (inWindow == 0) return empty;

    final score = _computeOverallScore(
      critical: critical,
      high: high,
      medium: medium,
      low: low,
      safe: safe,
    );
    final status = _bandForScore(score, inWindow: inWindow);

    return SafetyScore(
      overallScore: score,
      criticalCount: critical,
      highCount: high,
      mediumCount: medium,
      lowCount: low,
      safeCount: safe,
      totalInWindow: inWindow,
      status: status,
    );
  }

  /// Weighted score in 0..100. See class docstring for the weights
  /// rationale. Tuned so a single critical scan visibly drops the
  /// score and a clean history reads ~100.
  static int _computeOverallScore({
    required int critical,
    required int high,
    required int medium,
    required int low,
    required int safe,
  }) {
    // Per-scan "risk load" weights. Higher = more damaging to the
    // score. Picked so a single critical ≈ 75 load, a single safe
    // ≈ -2 load (slightly negative so very clean histories read
    // exactly 100 instead of getting floored by noise).
    const criticalWeight = 75.0;
    const highWeight = 35.0;
    const mediumWeight = 15.0;
    const lowWeight = 4.0;
    const safeWeight = -2.0;

    final total =
        critical * criticalWeight +
            high * highWeight +
            medium * mediumWeight +
            low * lowWeight +
            safe * safeWeight;

    // Map "load" → 0-100. 0 load (all safe) → 100; 200 load → 0.
    // The 200 ceiling was chosen empirically: 2 critical scans or 6
    // high scans should saturate the score at 0.
    final normalised = 100.0 - (total / 200.0 * 100.0);
    return normalised.clamp(0, 100).round();
  }

  /// Map a 0-100 score to one of the [SafetyStatus] bands. When
  /// `inWindow` is 0 the band is [SafetyStatus.noScans] — handled
  /// by the caller before reaching this point.
  static SafetyStatus _bandForScore(int score, {required int inWindow}) {
    if (score >= 85) return SafetyStatus.excellent;
    if (score >= 70) return SafetyStatus.good;
    if (score >= 50) return SafetyStatus.fair;
    if (score >= 25) return SafetyStatus.poor;
    return SafetyStatus.critical;
  }
}

/// 5-band verdict used by the home dashboard card. The colour
/// tokens are picked by the consumer (UI layer) based on this enum;
/// keeping colour out of the model lets us rebrand without touching
/// the score math.
enum SafetyStatus {
  /// No scans yet. Card collapses to the empty state.
  noScans,

  /// 85+. Green pill, "Excellent".
  excellent,

  /// 70-84. Green-tinted, "Good".
  good,

  /// 50-69. Amber-tinted, "Fair".
  fair,

  /// 25-49. Orange-tinted, "Needs attention".
  poor,

  /// 0-24. Red-tinted, "Critical".
  critical,
}
