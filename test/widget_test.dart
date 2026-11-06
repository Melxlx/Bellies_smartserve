import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bellies_smartserve/main.dart';

void main() {
  testWidgets('Splash screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const BelliesSmartServeApp());

    // Verify that the splash screen progress indicator exists
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Dispose the splash before its delay finishes, then drain that timer.
    // The smoke test does not initialize Supabase or exercise sign-in routing.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });
}
