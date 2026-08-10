// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:recognition_camera/main.dart';

void main() {
  testWidgets('App starts on splash screen then shows terms', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const RecognitionCameraApp());
    expect(find.text('WerWo'), findsOneWidget);
    expect(find.text('Know the origin.\nUnderstand the impact.'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pumpAndSettle();

    expect(find.text('Before you start'), findsOneWidget);

    // The consent gate states the limits rather than burying them. This is
    // the only screen every user sees, and it is where the badge vocabulary
    // is introduced — asserted here so the wording cannot quietly drift back
    // into a paragraph nobody reads.
    expect(find.text('Most answers are inferences'), findsOneWidget);
    expect(
      find.text('Every claim says how far it can be trusted'),
      findsOneWidget,
    );
    // Below the fold on a test-sized viewport, so it is scrolled to rather
    // than assumed absent.
    await tester.scrollUntilVisible(
      find.text('Not advice, and not a compliance record'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('Not advice, and not a compliance record'),
      findsOneWidget,
    );

    // Both actions name their consequence.
    expect(find.text('Agree and continue'), findsOneWidget);
    expect(find.text('Decline and close the app'), findsOneWidget);
  });
}
