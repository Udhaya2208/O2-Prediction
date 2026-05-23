// Basic smoke test for O2-Vision app.

import 'package:flutter_test/flutter_test.dart';
import 'package:o2_vision/main.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const O2VisionApp());

    // Verify the app renders (Scanner screen shows by default).
    expect(find.text('Tree Scanner'), findsOneWidget);
  });
}
