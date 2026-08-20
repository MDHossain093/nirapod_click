// Smoke test for LoginPage — verifies the screen builds without
// throwing. Doesn't touch Firebase (the form doesn't call any auth
// method until the user submits), so we can run it without mocks.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nirapod_click/screens/auth/login_page.dart';

void main() {
  testWidgets('LoginPage renders without throwing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoginPage()),
    );
    // Allow one frame for animations / image error builders to settle.
    await tester.pump();

    // The brand mark + tagline must be present.
    expect(find.text('NirapodClick'), findsOneWidget);
    expect(find.text('ক্লিক করার আগে যাচাই করুন।'), findsOneWidget);
    // Form fields.
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
  });
}