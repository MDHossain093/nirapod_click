/// Smoke test for the redesigned CheckScreen 2x2 grid.
///
/// All four scanner tiles should be visible in both English and
/// Bangla without the user having to scroll. Tap targets are not
/// exercised here — that's covered by manual testing on device.
///
/// Run with:
///   flutter test test/check_screen_smoke_test.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nirapod_click/core/locale/app_locale.dart';
import 'package:nirapod_click/screens/check/check_screen.dart';

void main() {
  testWidgets('CheckScreen renders all 5 scanner tile titles (English)',
      (tester) async {
    // Phone-sized viewport — the real device shape this screen
    // targets. The 800×600 default leaves the grid overflowing.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      AppLocaleScope(
        locale: AppLocale.english,
        onChanged: (_) {},
        child: const MaterialApp(home: CheckScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Message'), findsOneWidget);
    expect(find.text('URL'), findsOneWidget);
    expect(find.text('Screenshot'), findsOneWidget);
    expect(find.text('Phone'), findsOneWidget);
    // The QR scanner was added as a 5th, full-width tile below the
    // 2x2 grid. Asserting on its title confirms the new tile is
    // wired in and the locale lookup for the new key resolves.
    expect(find.text('QR Code'), findsOneWidget);
    // Heading copy confirms the area above the grid renders too.
    expect(find.text('What do you want to check?'), findsOneWidget);
    // ignore: avoid_print
    print('[check EN] 2x2 grid + QR tile render 5 titles ✓');
  });

  testWidgets('CheckScreen renders all 5 scanner tile titles (Bangla)',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      AppLocaleScope(
        locale: AppLocale.bangla,
        onChanged: (_) {},
        child: const MaterialApp(home: CheckScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('বার্তা'), findsOneWidget);
    expect(find.text('লিংক'), findsOneWidget);
    expect(find.text('স্ক্রিনশট'), findsOneWidget);
    expect(find.text('ফোন'), findsOneWidget);
    expect(find.text('QR কোড'), findsOneWidget);
    // Heading copy confirms the area above the grid renders too.
    expect(find.text('কী যাচাই করতে চান?'), findsOneWidget);
    // ignore: avoid_print
    print('[check BN] 2x2 grid + QR tile render 5 titles ✓');
  });
}