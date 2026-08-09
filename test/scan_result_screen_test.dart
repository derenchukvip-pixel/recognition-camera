import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recognition_camera/domain/models/recognition_result.dart';
import 'package:recognition_camera/domain/models/report_from_recognition.dart';
import 'package:recognition_camera/presentation/report/product_report_view.dart';

/// The regression test for the gap this work closed.
///
/// The provenance model, the adapters and the badges all existed and were all
/// covered — but the live scan bypassed every one of them and rendered the
/// backend's strings directly, so the app shipped with the bug its own test
/// suite said was fixed. Unit tests on the adapter cannot catch that: they
/// prove the mapping is right, not that anyone calls it.
///
/// So this one goes through the widget. It pumps the exact response the
/// backend produces and asserts on what a user would actually read on screen.
Future<void> _pumpResult(WidgetTester tester, String backendResult) async {
  final report = RecognitionResult.fromResponse(backendResult)
      .toReport(imagePath: '/tmp/scan.jpg');

  await tester.pumpWidget(
    MaterialApp(
      home: ProductReportView(
        report: report,
        // Stands in for `Image.file`: there is no file system in a widget
        // test, and the photo is not what this test is about.
        imageBuilder: (_) => const ColoredBox(color: Color(0xFFEEEEEE)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _lego = 'Recycling Truck 42107\n\n'
    'Production origin and headquarters:\n'
    '- Estimated production origin of Recycling Truck 42107: '
    'Czech Republic 70%, Hungary 30%\n'
    '- Company: LEGO\n'
    '- Country of the HQ: Denmark\n'
    '- Country where the company pays taxes and receives profit: Denmark';

/// Badges are searched inside the headline and the claim card only.
///
/// The legend at the foot of the screen spells out all three badges by
/// definition — it says what "Verified" means — so a screen-wide search for
/// the word always finds one and would quietly pass no matter how wrong the
/// claims above it were.
Finder _badge(String text) => find.descendant(
      of: find.byKey(reportClaimsKey),
      matching: find.text(text),
    );

Finder _headlineBadge(String text) => find.descendant(
      of: find.byKey(reportHeadlineKey),
      matching: find.text(text),
    );

void main() {
  testWidgets('a live scan shows countries without invented percentages',
      (tester) async {
    await _pumpResult(tester, _lego);

    expect(find.text('Czech Republic, Hungary'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is Text && (w.data?.contains('%') ?? false),
      ),
      findsNothing,
      reason: 'no percentage may survive to the screen, in any field',
    );
  });

  testWidgets('a live scan never shows a Verified badge', (tester) async {
    await _pumpResult(tester, _lego);

    expect(_badge('VERIFIED'), findsNothing);
    expect(_headlineBadge('VERIFIED'), findsNothing);
    expect(_badge('ESTIMATED'), findsWidgets);
    expect(_headlineBadge('ESTIMATED'), findsOneWidget);

    // The legend is still there, and still defines all three. That is the
    // point of scoping the assertions above rather than deleting it.
    expect(
      find.descendant(
        of: find.byKey(provenanceLegendKey),
        matching: find.text('VERIFIED'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the reading is attributed to the photo it came from',
      (tester) async {
    await _pumpResult(tester, _lego);

    expect(find.text('Recycling Truck 42107'), findsOneWidget);
    expect(find.text('by LEGO'), findsOneWidget);
    // The barcode header belongs to barcode scans only. A photo scan showing
    // "SCANNED BARCODE" would claim a reading that never happened.
    expect(find.text('SCANNED BARCODE'), findsNothing);
  });

  testWidgets('an unidentified product says so instead of guessing',
      (tester) async {
    await _pumpResult(
      tester,
      'Not identified\n\n'
      'Production origin and headquarters:\n'
      '- Estimated production origin of Not identified: Not identified\n'
      '- Company: Not identified\n'
      '- Country of the HQ: Not identified\n'
      '- Country where the company pays taxes and receives profit: '
      'Not identified',
    );

    expect(find.text('Product not identified'), findsOneWidget);
    expect(find.text('Not disclosed'), findsWidgets);
    expect(_badge('VERIFIED'), findsNothing);
    expect(_badge('ESTIMATED'), findsNothing);
    expect(_badge('UNKNOWN'), findsWidgets);
  });
}
