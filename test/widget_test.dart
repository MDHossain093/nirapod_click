// Basic widget smoke test.
//
// NirapodClickApp calls Firebase.initializeApp() in main(), so we can't pump it
// directly in a widget test without mocking the Firebase plugins. This test
// verifies the test harness itself boots.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Test harness boots', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('NirapodClick'))),
      ),
    );

    expect(find.text('NirapodClick'), findsOneWidget);
  });
}