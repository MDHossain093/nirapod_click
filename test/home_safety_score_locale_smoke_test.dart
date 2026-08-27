/// Bug-repro smoke: the user reported "safety score card shows 100 in BN
/// locale even though EN shows a real value". This test forces
/// `SafetyScore.compute` and the locale-dependent formatters to run on
/// a controlled input (1 critical scan) under both locales and prints
/// the rendered headline + ring center number for each.
///
/// Run with:
///   flutter test test/home_safety_score_locale_smoke_test.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nirapod_click/core/locale/app_locale.dart';
import 'package:nirapod_click/core/locale/digits.dart';
import 'package:nirapod_click/core/locale/localizer.dart';
import 'package:nirapod_click/core/safety_score.dart';
import 'package:nirapod_click/models/risk_result.dart';
import 'package:nirapod_click/services/checker_repository.dart' show HistoryEntry;

/// Drives a tiny in-memory [Localizer] so we can flip locales without
/// needing an [AppLocaleScope] in the widget tree.
String _renderHeadline(int score, AppLocale locale) {
  Localizer.instance.setLocale(locale);
  return '${Localizer.instance.formatNumber(score)} / '
      '${toLocalizedDigits(100, locale)}';
}

String _renderRingCenter(int score, AppLocale locale) {
  Localizer.instance.setLocale(locale);
  return Localizer.instance.formatNumber(score);
}

void main() {
  final now = DateTime(2026, 8, 27, 12);

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
        createdAt: Timestamp.fromDate(createdAt),
      );

  test('safety score renders correctly in EN locale', () {
    Localizer.instance.setLocale(AppLocale.english);
    final entries = <HistoryEntry>[mk(RiskLevel.critical, now)];
    final score = SafetyScore.compute(entries, now: now);
    final headline = _renderHeadline(score.overallScore, AppLocale.english);
    final ringCenter =
        _renderRingCenter(score.overallScore, AppLocale.english);
    // ignore: avoid_print
    print(
      '[EN] overallScore=${score.overallScore} '
      'band=${score.status.name} '
      'headline="$headline" '
      'ringCenter="$ringCenter"',
    );
    expect(score.overallScore, 63,
        reason: '1 critical scan must score 63 (not 100)');
    expect(headline, '63 / 100');
    expect(ringCenter, '63');
  });

  test('safety score renders correctly in BN locale', () {
    Localizer.instance.setLocale(AppLocale.bangla);
    final entries = <HistoryEntry>[mk(RiskLevel.critical, now)];
    final score = SafetyScore.compute(entries, now: now);
    final headline = _renderHeadline(score.overallScore, AppLocale.bangla);
    final ringCenter =
        _renderRingCenter(score.overallScore, AppLocale.bangla);
    // ignore: avoid_print
    print(
      '[BN] overallScore=${score.overallScore} '
      'band=${score.status.name} '
      'headline="$headline" '
      'ringCenter="$ringCenter"',
    );
    expect(score.overallScore, 63);
    // 63 in Bangla digits → '৬৩'
    expect(headline, '৬৩ / ১০০');
    expect(ringCenter, '৬৩');
  });

  test('locale switch on the same data must NOT change the score', () {
    final entries = <HistoryEntry>[mk(RiskLevel.critical, now)];
    final en = SafetyScore.compute(entries, now: now);
    Localizer.instance.setLocale(AppLocale.bangla);
    final bn = SafetyScore.compute(entries, now: now);
    // ignore: avoid_print
    print(
      '[locale-switch sanity] EN=${en.overallScore} '
      'BN=${bn.overallScore} (must be equal)',
    );
    expect(en.overallScore, bn.overallScore,
        reason: 'locale must not affect the math');
  });
}