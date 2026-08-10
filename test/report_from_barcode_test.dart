import 'package:flutter_test/flutter_test.dart';
import 'package:recognition_camera/domain/models/product_report.dart';
import 'package:recognition_camera/domain/models/report_from_barcode.dart';
import 'package:recognition_camera/domain/provenance.dart';

/// A valid EAN-13 registered to a Danish member organisation (prefix 570).
const _lego = '5702016616545';

/// The same digits with a broken check digit.
const _misread = '4006381333932';

Map<String, dynamic> _offRecord({
  String? name = 'Recycling Truck 42107',
  String? brands = 'LEGO',
  String? manufacturingPlaces,
}) =>
    {
      if (name != null) 'product_name': name,
      if (brands != null) 'brands': brands,
      if (manufacturingPlaces != null)
        'manufacturing_places': manufacturingPlaces,
    };

void main() {
  group('a barcode scan is attributed to the digits, not to a camera', () {
    test('source is the barcode and there is no image', () {
      final report = reportFromBarcode(_lego);

      expect(report.source, ScanSource.barcode);
      expect(report.barcode, _lego);
      expect(report.imagePath, isNull);
    });

    test('tax jurisdiction is absent rather than unknown', () {
      // A registry lookup never asks the question, so the row is dropped
      // instead of answered with a shrug. Compare the photo path, which does
      // ask and therefore reports Unknown.
      expect(reportFromBarcode(_lego).taxJurisdiction, isNull);
    });
  });

  group('the registry claim stands on its own', () {
    test('a valid barcode resolves to its member organisation', () {
      final claim = reportFromBarcode(_lego).registeredIn;

      expect(claim.provenance, Provenance.verified);
      expect(claim.value, 'Denmark');
      expect(claim.source, 'GS1 prefix 570');
      // The correction almost every user needs: the prefix is where the brand
      // owner registered, not where the goods were made.
      expect(claim.caveat, contains('not where the product was made'));
    });

    test('a failed check digit earns no verified claim anywhere', () {
      final report = reportFromBarcode(_misread);

      expect(report.registeredIn.provenance, Provenance.unknown);
      expect(report.registeredIn.caveat, contains('check digit'));
      expect(report.hasVerifiedClaim, isFalse);
    });
  });

  group('when Open Food Facts has no record', () {
    test('the report is still built and says why the fields are empty', () {
      final report = reportFromBarcode(_lego);

      expect(report.productName.provenance, Provenance.unknown);
      expect(report.productName.caveat, contains('not in Open Food Facts'));
      // The point of the whole path: no product record, and still one
      // reproducible, attributed answer on screen.
      expect(report.registeredIn.provenance, Provenance.verified);
      expect(report.hasVerifiedClaim, isTrue);
    });
  });

  group('when Open Food Facts has a record', () {
    test('name and brand are verified and attributed', () {
      final report =
          reportFromBarcode(_lego, openFoodFactsProduct: _offRecord());

      expect(report.productName.value, 'Recycling Truck 42107');
      expect(report.productName.provenance, Provenance.verified);
      expect(report.productName.source, 'Open Food Facts');
      expect(report.brand.value, 'LEGO');
    });

    test('the verified badge is qualified, never bare', () {
      final claim =
          reportFromBarcode(_lego, openFoodFactsProduct: _offRecord()).brand;

      // Verified means reproducible and attributed — not audited. A crowd
      // -sourced field carrying the badge without saying so is the same
      // overclaim the invented percentages were, in a nicer font.
      expect(claim.caveat, contains('community-maintained'));
    });

    test('an empty field in the record does not become a finding', () {
      final report = reportFromBarcode(
        _lego,
        openFoodFactsProduct: _offRecord(name: '', brands: 'Unknown'),
      );

      expect(report.productName.provenance, Provenance.unknown);
      expect(report.brand.provenance, Provenance.unknown);
    });

    test('a declared manufacturing place is reported with its origin', () {
      final claim = reportFromBarcode(
        _lego,
        openFoodFactsProduct: _offRecord(manufacturingPlaces: 'Billund'),
      ).manufacturedIn;

      expect(claim.value, 'Billund');
      expect(claim.provenance, Provenance.verified);
      expect(claim.caveat, contains('not by the manufacturer'));
    });

    test('headquarters stays unknown — the database does not record it', () {
      final report =
          reportFromBarcode(_lego, openFoodFactsProduct: _offRecord());

      expect(report.headquarters.provenance, Provenance.unknown);
      expect(report.headquarters.caveat, contains('does not record'));
    });
  });
}
