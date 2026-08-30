/// Smoke test for the QrCheckerScreen.
///
/// The screen wires up the camera via `mobile_scanner` and asks
/// for camera permission via `permission_handler`, neither of
/// which work in `flutter test`. We exercise the *static* UI
/// states instead:
///
///   * Idle / pre-permission prompt — verifies the icon, title,
///     body copy, and "Enter QR text manually" affordance render.
///   * Permission-denied state — directly constructed via the same
///     internal widget tree, but exposed through a public test
///     surface by injecting a stage. (Not done in v1 — the screen's
///     stage enum is private; the manual-entry dialog is reachable
///     via the idle prompt and exercises the same code path.)
///
/// The classifier that drives the routing is unit-tested in
/// `qr_payload_classifier_test.dart` — exhaustive coverage lives
/// there.
///
/// Run with:
///   flutter test test/qr_checker_smoke_test.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nirapod_click/core/locale/app_locale.dart';
import 'package:nirapod_click/screens/qr_checker/qr_checker_screen.dart';

void main() {
  testWidgets(
    'QrCheckerScreen renders the idle permission prompt (English)',
    (tester) async {
      // Phone-sized viewport — the same shape the screen is
      // designed for. The default `flutter test` viewport (800x600)
      // would clip the centered column.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        AppLocaleScope(
          locale: AppLocale.english,
          onChanged: (_) {},
          child: const MaterialApp(
            home: QrCheckerScreen(skipAutoPermission: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // App bar title.
      expect(find.text('QR Code'), findsOneWidget);
      // The idle prompt reuses the same string for both the title
      // and the CTA button, so we expect two matches.
      expect(find.text('Allow camera access'), findsNWidgets(2));
      // The "Enter QR text manually" fallback renders once in the
      // idle state (as a TextButton under the primary CTA). The
      // bottom-banner copy is part of the scanning stage, not idle,
      // so we assert exactly one occurrence here.
      expect(find.text('Enter QR text manually'), findsOneWidget);
      // The subheading explains what the camera will do — confirms
      // body copy renders.
      expect(
        find.textContaining('Point your camera'),
        findsOneWidget,
      );
      // ignore: avoid_print
      print('[qr EN] idle prompt renders ✓');
    },
  );

  testWidgets(
    'QrCheckerScreen renders the idle permission prompt (Bangla)',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        AppLocaleScope(
          locale: AppLocale.bangla,
          onChanged: (_) {},
          child: const MaterialApp(
            home: QrCheckerScreen(skipAutoPermission: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('QR কোড'), findsOneWidget);
      // Two copies: title + CTA button.
      expect(find.text('ক্যামেরা অ্যাক্সেস দিন'), findsNWidgets(2));
      expect(find.text('QR-এর লেখা ম্যানুয়ালি লিখুন'), findsOneWidget);
      expect(find.textContaining('ক্যামেরা ধরলে'), findsOneWidget);
      // ignore: avoid_print
      print('[qr BN] idle prompt renders ✓');
    },
  );

  testWidgets(
    'Tapping "Enter QR text manually" opens the manual-entry dialog',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        AppLocaleScope(
          locale: AppLocale.english,
          onChanged: (_) {},
          child: const MaterialApp(
            home: QrCheckerScreen(skipAutoPermission: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the manual-entry fallback. In the idle state there's
      // exactly one copy of "Enter QR text manually" rendered (the
      // TextButton below the primary CTA). Tap that.
      await tester.tap(find.text('Enter QR text manually'));
      await tester.pumpAndSettle();

      // The dialog title and hint text appear once the dialog is
      // up. The dialog title re-uses the manual-entry label, so we
      // expect two copies of that string (the original button +
      // the dialog title) plus the dialog hint.
      expect(find.text('Enter QR text manually'), findsNWidgets(2));
      expect(find.text('Paste the QR code text below'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      // ignore: avoid_print
      print('[qr EN] manual-entry dialog opens ✓');
    },
  );
}