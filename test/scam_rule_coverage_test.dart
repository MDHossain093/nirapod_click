import 'package:flutter_test/flutter_test.dart';
import 'package:nirapod_click/data/default_scam_rules.dart';

/// Smoke guard for `defaultScamRules`. Every rule shipped with the APK
/// MUST have at least one English keyword AND at least one Bangla
/// keyword so the bundled fallback stays useful for both locales.
/// Catches silent one-language drift when someone adds a new category.
void main() {
  test('every ScamRule has both English and Bangla keywords', () {
    // Unicode range for Bengali script (U+0980..U+09FF).
    final bengaliRange = RegExp(r'[\u0980-\u09FF]');
    // Crude "Latin" detector: anything that's a letter and NOT in the
    // Bengali range. Numbers and CJK are ignored — we only care that
    // there's at least one romanised keyword for an English-speaking
    // user to recognise.
    final hasLatin = RegExp(r'[A-Za-z]');

    for (final rule in defaultScamRules) {
      expect(
        rule.keywords,
        isNotEmpty,
        reason: '${rule.id} has no keywords at all',
      );

      final hasBn = rule.keywords.any(bengaliRange.hasMatch);
      final hasEn = rule.keywords.any(hasLatin.hasMatch);

      expect(
        hasBn,
        isTrue,
        reason:
            '${rule.id} (${rule.category}) is missing a Bangla keyword '
            '— bundled fallback will be useless for BN-mode users.',
      );
      expect(
        hasEn,
        isTrue,
        reason:
            '${rule.id} (${rule.category}) is missing an English keyword '
            '— bundled fallback will be useless for EN-mode users.',
      );
    }
  });

  test('every ScamRule has a unique id', () {
    final ids = defaultScamRules.map((r) => r.id).toList();
    expect(
      ids.toSet().length,
      ids.length,
      reason: 'duplicate rule id found: $ids',
    );
  });

  test('every ScamRule score is in 0..100', () {
    for (final rule in defaultScamRules) {
      expect(
        rule.score,
        inInclusiveRange(0, 100),
        reason: '${rule.id} score ${rule.score} out of range',
      );
    }
  });

  test('rule count is at least the original 6 (regression guard)', () {
    // Original 6: urgency, payment, sensitive, prize, account, job.
    // We added 15 BD-specific ones. The number must not regress below
    // 6 even if a refactor accidentally drops entries.
    expect(defaultScamRules.length, greaterThanOrEqualTo(6));
  });
}
