import 'package:flutter_test/flutter_test.dart';
import 'package:recognition_camera/domain/models/history_item.dart';
import 'package:recognition_camera/domain/models/product_report.dart';
import 'package:recognition_camera/domain/models/report_from_history.dart';
import 'package:recognition_camera/domain/models/saved_product.dart';
import 'package:recognition_camera/domain/provenance.dart';

HistoryItem _item({
  String productName = 'Recycling Truck 42107',
  String companyName = 'LEGO',
  String? productionOrigin,
  String? hqCountry = 'Denmark',
}) =>
    HistoryItem(
      id: '1',
      productName: productName,
      companyName: companyName,
      imagePath: '/tmp/a.jpg',
      originalImagePath: '/tmp/b.jpg',
      resultText: '',
      productionOrigin: productionOrigin,
      hqCountry: hqCountry,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  group('legacy percentages', () {
    test('are stripped, leaving the country names', () {
      final report =
          _item(productionOrigin: 'Czech Republic x70%, Hungary x30%').toReport();

      expect(report.manufacturedIn.displayValue, 'Czech Republic, Hungary');
      expect(report.manufacturedIn.displayValue, isNot(contains('%')));
      expect(report.manufacturedIn.displayValue, isNot(contains('70')));
    });

    test('handles the other recorded shapes', () {
      expect(
        _item(productionOrigin: 'Denmark 50%, Czech Republic 25%, Mexico 25%')
            .toReport()
            .manufacturedIn
            .displayValue,
        'Denmark, Czech Republic, Mexico',
      );
      expect(
        _item(productionOrigin: 'China 90 %, Other countries 10 %')
            .toReport()
            .manufacturedIn
            .displayValue,
        'China, Other countries',
      );
    });

    test('a string of nothing but numbers collapses to unknown', () {
      final report = _item(productionOrigin: '70%, 30%').toReport();
      expect(report.manufacturedIn.provenance, Provenance.unknown);
    });
  });

  group('provenance of recovered records', () {
    test('nothing from history is ever marked verified', () {
      final report = _item(productionOrigin: 'China x90%').toReport();
      final claims = [
        report.productName,
        report.brand,
        report.registeredIn,
        report.manufacturedIn,
        report.headquarters,
      ];
      expect(
        claims.map((c) => c.provenance),
        everyElement(isNot(Provenance.verified)),
      );
      expect(report.hasVerifiedClaim, isFalse);
    });

    test('registeredIn is unknown and explains why', () {
      final claim = _item().toReport().registeredIn;
      expect(claim.provenance, Provenance.unknown);
      expect(claim.caveat, contains('Rescan the barcode'));
    });

    test('old placeholder text collapses to unknown, not shown as a finding',
        () {
      final report = _item(
        productName: 'Not identified',
        companyName: 'Unknown company',
        hqCountry: null,
      ).toReport();

      expect(report.productName.provenance, Provenance.unknown);
      expect(report.brand.provenance, Provenance.unknown);
      expect(report.headquarters.provenance, Provenance.unknown);
    });

    test('a real recovered value is estimated and attributed', () {
      final claim = _item().toReport().brand;
      expect(claim.provenance, Provenance.estimated);
      expect(claim.value, 'LEGO');
      expect(claim.source, contains('earlier version'));
    });
  });

  group('SavedProduct', () {
    test('maps the same way as HistoryItem', () {
      final saved = SavedProduct(
        id: '1',
        productName: 'Bonsai Tree 10281',
        companyName: 'LEGO',
        imagePath: '/tmp/a.jpg',
        originalImagePath: '/tmp/b.jpg',
        productionOrigin: 'Denmark x50%, Mexico x50%',
        hqCountry: 'Denmark',
        createdAt: DateTime(2026, 1, 1),
      );

      final report = saved.toReport();
      expect(report.manufacturedIn.displayValue, 'Denmark, Mexico');
      expect(report.hasVerifiedClaim, isFalse);
      expect(report.source, ScanSource.photo);
    });
  });
}
