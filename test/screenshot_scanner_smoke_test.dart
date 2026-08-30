/// Smoke test for the redesigned ScreenshotScannerScreen.
///
/// Asserts the idle stage renders the picker placeholder + format hint
/// and that the new two-stage flow's Analyze CTA does NOT show up
/// before an image is picked. The OCR / analyze stages are exercised
/// by manual on-device testing because they require ML Kit + the
/// platform image picker, neither of which work in `flutter test`.
///
/// Run with:
///   flutter test test/screenshot_scanner_smoke_test.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nirapod_click/core/locale/app_locale.dart';
import 'package:nirapod_click/models/subscription.dart';
import 'package:nirapod_click/screens/screenshot_scanner/screenshot_scanner_screen.dart';
import 'package:nirapod_click/services/subscription_service.dart';

void main() {
  setUpAll(() async {
    // ScreenshotScannerScreen constructs ScreenshotHybridAnalyzer → AiService
    // in its State, which reads GEMINI_API_KEY via flutter_dotenv. In a real
    // app `AppEnv.load()` runs from `main()`, but widget tests don't go
    // through `main()`. `testLoad` seeds the dotenv singleton with an empty
    // map so the read returns "" instead of throwing NotInitializedError.
    dotenv.testLoad();
  });

  testWidgets(
      'ScreenshotScannerScreen renders the picker placeholder (English)',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = SubscriptionService.instance;
    service.emitForTest(SubscriptionState(
      status: SubscriptionStatus.free,
      limits: const PlanLimits(
        messageScansRemaining: 5,
        screenshotScansRemaining: 5,
      ),
    ));

    await tester.pumpWidget(
      AppLocaleScope(
        locale: AppLocale.english,
        onChanged: (_) {},
        child: MaterialApp(
          home: SubscriptionScope(
            service: service,
            child: const ScreenshotScannerScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tap to select screenshot'), findsOneWidget);
    expect(find.text('JPG, PNG'), findsOneWidget);
    // Analyze CTA must not render until the user has picked an image.
    expect(find.text('Analyze'), findsNothing);
    // ignore: avoid_print
    print('[screenshot EN] picker placeholder renders, Analyze CTA absent ✓');
  });

  testWidgets(
      'ScreenshotScannerScreen renders the picker placeholder (Bangla)',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = SubscriptionService.instance;
    service.emitForTest(SubscriptionState(
      status: SubscriptionStatus.free,
      limits: const PlanLimits(
        messageScansRemaining: 5,
        screenshotScansRemaining: 5,
      ),
    ));

    await tester.pumpWidget(
      AppLocaleScope(
        locale: AppLocale.bangla,
        onChanged: (_) {},
        child: MaterialApp(
          home: SubscriptionScope(
            service: service,
            child: const ScreenshotScannerScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('স্ক্রিনশট নির্বাচন করতে ট্যাপ করুন'), findsOneWidget);
    expect(find.text('বিশ্লেষণ করুন'), findsNothing);
    // ignore: avoid_print
    print('[screenshot BN] picker placeholder renders, Analyze CTA absent ✓');
  });
}