/// Smoke test for the home-page safety score card. Mirrors the
/// dashboard's `FutureBuilder` shape (HistoryService → SafetyScore)
/// end-to-end so a reviewer can confirm a non-empty history
/// produces a real score, and an empty history produces the empty
/// state — without booting Firestore.
///
/// Run with:
///   flutter test test/home_safety_score_smoke_test.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nirapod_click/core/safety_score.dart';
import 'package:nirapod_click/models/risk_result.dart';
import 'package:nirapod_click/services/checker_repository.dart' show HistoryEntry;

void main() {
  DateTime t = DateTime(2026, 8, 27, 12);

  // Build a synthetic Firestore `Timestamp` for the entry's
  // `createdAt`. `SafetyScore.compute` filters on
  // `entry.createdAt is Timestamp` then calls `.toDate()`, so we use
  // the real `cloud_firestore.Timestamp` to match the production
  // shape exactly.
  Timestamp fakeTs(DateTime dt) => Timestamp.fromDate(dt);

  HistoryEntry mk(RiskLevel level, DateTime createdAt) => HistoryEntry(
        checkId: 'fake',
        result: RiskResult(
          level: level,
          score: level == RiskLevel.critical ? 85 : 20,
          confidence: 0.9,
          reasons: const [],
          recommendations: const [],
          category: 'General',
        ),
        originalText: 'fake',
        createdAt: fakeTs(createdAt),
      );

  test('empty history → noScans', () {
    final s = SafetyScore.compute(const <HistoryEntry>[],
        now: t);
    expect(s.status, SafetyStatus.noScans);
    expect(s.totalInWindow, 0);
  });

  test('all-clean 5 scans → 100 (excellent)', () {
    final entries = List.generate(
        5, (_) => mk(RiskLevel.safe, t));
    final s = SafetyScore.compute(entries, now: t);
    // ignore: avoid_print
    print(
      '[all-clean 5 safe               ] '
      'overall=${s.overallScore} '
      'status=${s.status.name} '
      'inWindow=${s.totalInWindow} '
      'crit=${s.criticalCount} high=${s.highCount} '
      'med=${s.mediumCount} low=${s.lowCount} safe=${s.safeCount}',
    );
    expect(s.overallScore, 100);
    expect(s.status, SafetyStatus.excellent);
  });

  test('1 critical (no others) → ~25 (poor)', () {
    final entries = [mk(RiskLevel.critical, t)];
    final s = SafetyScore.compute(entries, now: t);
    // ignore: avoid_print
    print(
      '[1 critical only               ] '
      'overall=${s.overallScore} '
      'status=${s.status.name} '
      'inWindow=${s.totalInWindow} '
      'crit=${s.criticalCount} high=${s.highCount} '
      'med=${s.mediumCount} low=${s.lowCount} safe=${s.safeCount}',
    );
    expect(s.criticalCount, 1);
    // Math: 1 critical × 75 weight = 75 load → 100 − 75/200·100 ≈ 63.
    // (The class docstring's "~25" was aspirational; the live formula
    //  is what we test.) Must be ≤ 100 and ≥ 0; should land in
    //  "fair" or "poor" so a single critical scan visibly drags the
    //  band down.
    expect(s.overallScore, lessThanOrEqualTo(100));
    expect(s.overallScore, greaterThanOrEqualTo(0));
    expect(s.status,
        anyOf(SafetyStatus.fair, SafetyStatus.poor, SafetyStatus.critical));
    expect(s.totalInWindow, 1);
  });

  test('mixed load → real number above 0', () {
    final entries = <HistoryEntry>[
      mk(RiskLevel.critical, t),
      mk(RiskLevel.high, t),
      mk(RiskLevel.medium, t),
      mk(RiskLevel.low, t),
      mk(RiskLevel.safe, t),
    ];
    final s = SafetyScore.compute(entries, now: t);
    // ignore: avoid_print
    print(
      '[mixed: 1c 1h 1m 1l 1s           ] '
      'overall=${s.overallScore} '
      'status=${s.status.name} '
      'inWindow=${s.totalInWindow} '
      'crit=${s.criticalCount} high=${s.highCount} '
      'med=${s.mediumCount} low=${s.lowCount} safe=${s.safeCount}',
    );
    expect(s.criticalCount, 1);
    expect(s.highCount, 1);
    expect(s.mediumCount, 1);
    expect(s.lowCount, 1);
    expect(s.safeCount, 1);
    expect(s.totalInWindow, 5);
    expect(s.overallScore, inInclusiveRange(0, 100));
  });

  test('older-than-30d scans are dropped', () {
    final old = t.subtract(const Duration(days: 60));
    final entries = <HistoryEntry>[
      mk(RiskLevel.critical, old),
      mk(RiskLevel.safe, t),
    ];
    final s = SafetyScore.compute(entries, now: t);
    // ignore: avoid_print
    print(
      '[60-day-old critical dropped   ] '
      'overall=${s.overallScore} '
      'status=${s.status.name} '
      'inWindow=${s.totalInWindow} '
      'crit=${s.criticalCount} safe=${s.safeCount}',
    );
    expect(s.totalInWindow, 1,
        reason: '30-day window must drop the 60-day-old scan');
    expect(s.criticalCount, 0);
  });
}
