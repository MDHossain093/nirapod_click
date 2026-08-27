/// Bug-repro smoke: render the actual headline string that the home
/// page safety-score card builds, in both EN and BN locales. The
/// real card constructs `'${fmt(score.overallScore)} / 100'` where
/// `fmt = AppLocaleScope.of(context).formatNumber`. This test makes
/// the same call and asserts the exact rendered string for several
/// real scores.
///
/// Run with:
///   flutter test test/home_safety_score_widget_smoke_test.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nirapod_click/core/locale/app_locale.dart';

String _buildHeadline(AppLocale locale, int score) {
  // Equivalent of `AppLocaleScope.of(context).formatScore(score)` on a
  // real widget tree — the post-fix headline builder.
  late String result;
  late String ringCenter;
  runApp(
    AppLocaleScope(
      locale: locale,
      onChanged: (_) {},
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (ctx) {
            final scope = AppLocaleScope.of(ctx);
            result = scope.formatScore(score);
            ringCenter = scope.formatNumber(score);
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  return '$result | $ringCenter';
}

void main() {
  testWidgets('EN headline renders correctly for real scores',
      (tester) async {
    for (final score in [0, 37, 63, 85, 100]) {
      final out = _buildHeadline(AppLocale.english, score);
      // ignore: avoid_print
      print('[EN score=$score] $out');
      expect(out.contains('$score / 100'), isTrue);
      expect(out.contains('১'), isFalse,
          reason: 'English must not contain Bangla digits');
    }
  });

  testWidgets('BN headline renders correctly for real scores',
      (tester) async {
    for (final score in [0, 37, 63, 85, 100]) {
      final out = _buildHeadline(AppLocale.bangla, score);
      // ignore: avoid_print
      print('[BN score=$score] $out');
      // Convert ASCII to Bangla for assertion.
      const ascii = '0123456789';
      const bn = '০১২৩৪৫৬৭৮৯';
      var expected = '$score / 100';
      for (var i = 0; i < 10; i++) {
        expected = expected.replaceAll(ascii[i], bn[i]);
      }
      expect(out.contains(expected), isTrue,
          reason: 'BN headline must use Bangla digits');
      expect(out.contains('$score / 100'), isFalse,
          reason: 'BN headline must NOT contain ASCII digits');
    }
  });
}