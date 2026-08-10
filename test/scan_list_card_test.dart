import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recognition_camera/domain/models/product_report.dart';
import 'package:recognition_camera/domain/models/report_from_barcode.dart';
import 'package:recognition_camera/domain/models/recognition_result.dart';
import 'package:recognition_camera/domain/models/report_from_recognition.dart';
import 'package:recognition_camera/presentation/common/scan_list_card.dart';

Future<void> _pump(WidgetTester tester, ProductReport report) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ScanListCard(
          report: report,
          imagePath: '',
          fallbackImagePath: '',
          onTap: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ProductReport _photoScan() => RecognitionResult.fromResponse(
      'Recycling Truck 42107\n'
      '- Estimated production origin of Recycling Truck 42107: Denmark\n'
      '- Brand: LEGO\n',
    ).toReport(imagePath: '/tmp/scan.jpg');

void main() {
  testWidgets('a row shows how much of it was verified, before it is opened',
      (tester) async {
    // The point of the badge in the list. Without it a reproducible barcode
    // reading and a model's guess look identical until you tap them, and the
    // distinction the app is built around exists only on the detail screen.
    await _pump(
      tester,
      reportFromBarcode(
        '5702016616545',
        openFoodFactsProduct: const {
          'product_name': 'Recycling Truck 42107',
          'brands': 'LEGO',
        },
      ),
    );

    expect(find.text('Recycling Truck 42107'), findsOneWidget);
    expect(find.text('VERIFIED'), findsOneWidget);
  });

  testWidgets('a photo scan is marked as an estimate in the list too',
      (tester) async {
    await _pump(tester, _photoScan());

    expect(find.text('ESTIMATED'), findsOneWidget);
    expect(find.text('VERIFIED'), findsNothing);
  });

  testWidgets('an unidentified product is not given a filler name',
      (tester) async {
    await _pump(tester, reportFromBarcode('5702016616545'));

    expect(find.text('Product not identified'), findsOneWidget);
    // The digits stand in for the brand, because that is what this scan
    // actually has. "Unknown company" would assert a lookup that failed.
    expect(find.text('5702016616545'), findsOneWidget);
    expect(find.text('Unknown company'), findsNothing);
  });
}
