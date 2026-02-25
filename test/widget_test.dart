// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:recognition_camera/main.dart';

void main() {
  testWidgets('App starts on splash screen then shows terms', (WidgetTester tester) async {
    await tester.pumpWidget(const RecognitionCameraApp());
    expect(find.text('WerWo'), findsOneWidget);
    expect(find.text('Know the origin.\nUnderstand the impact.'), findsOneWidget);

  await tester.pump(const Duration(milliseconds: 2300));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.maxLines == 2 &&
            widget.text.toPlainText().contains('Terms of Use'),
      ),
      findsOneWidget,
    );
  });
}
