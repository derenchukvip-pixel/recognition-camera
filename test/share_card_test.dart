import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recognition_camera/domain/models/recognition_result.dart';
import 'package:recognition_camera/domain/models/report_from_barcode.dart';
import 'package:recognition_camera/domain/models/report_from_recognition.dart';
import 'package:recognition_camera/presentation/report/share_card.dart';

Future<void> _pump(WidgetTester tester, Widget card) async {
  // The card is authored at 1080 wide and taller than any test viewport, so
  // the surface is sized to it. Off-screen children are not built, and this
  // test is about what the image contains.
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(home: Material(child: SingleChildScrollView(child: card))),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the legend travels with the image, always', (tester) async {
    // The reason this is a purpose-built card and not a screenshot. A picture
    // of a country under a green tick, arriving in a chat with no
    // explanation, is the claim this app exists to stop making.
    await _pump(
      tester,
      ShareCard(
        report: reportFromBarcode(
          '5702016616545',
          openFoodFactsProduct: const {
            'product_name': 'Recycling Truck 42107',
            'brands': 'LEGO',
          },
        ),
      ),
    );

    expect(find.text('HOW TO READ THIS'), findsOneWidget);
    expect(find.text('VERIFIED'), findsWidgets);
    expect(find.text('ESTIMATED'), findsOneWidget);
    expect(find.text('UNKNOWN'), findsWidgets);
  });

  testWidgets('a barcode scan carries the digits it was read from',
      (tester) async {
    await _pump(tester, ShareCard(report: reportFromBarcode('5702016616545')));

    // The evidence travels; on this path the digits are what every Verified
    // badge traces back to.
    expect(find.text('5702016616545'), findsOneWidget);
    expect(find.text('Denmark'), findsOneWidget);
  });

  testWidgets('a photo scan shares no photo and no verified badge',
      (tester) async {
    final report = RecognitionResult.fromResponse(
      'Bonsai Tree 10281\n'
      '- Estimated production origin of Bonsai Tree 10281: Denmark\n'
      '- Brand: LEGO\n'
      '- Country of the HQ: Denmark',
    ).toReport(imagePath: '/tmp/scan.jpg');

    await _pump(tester, ShareCard(report: report));

    expect(find.text('Bonsai Tree 10281'), findsOneWidget);
    // No Image widget: the sender's snapshot is not evidence, and including
    // it invites the recipient to read it as such.
    expect(find.byType(Image), findsNothing);
    // Only the legend's definition of VERIFIED, never a claim wearing it.
    expect(find.text('VERIFIED'), findsOneWidget);
  });

  testWidgets('an unidentified product says so on the card too',
      (tester) async {
    await _pump(tester, ShareCard(report: reportFromBarcode('4006381333932')));

    expect(find.text('Product not identified'), findsOneWidget);
  });
}
