import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:welltrack/app.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: WellTrackApp(),
      ),
    );

    // Verify app shows initialization loading
    expect(find.text('Initializing WellTrack...'), findsOneWidget);
  });
}
