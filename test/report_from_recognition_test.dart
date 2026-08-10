import 'package:flutter_test/flutter_test.dart';
import 'package:recognition_camera/domain/models/product_report.dart';
import 'package:recognition_camera/domain/models/recognition_result.dart';
import 'package:recognition_camera/domain/models/report_from_recognition.dart';
import 'package:recognition_camera/domain/provenance.dart';

/// The exact shape the FastAPI backend returns, assembled the way `main.py`
/// assembles it. Parsed rather than hand-built so these tests cover the join
/// between the response parser and the provenance adapter — the seam the live
/// path actually runs through.
RecognitionResult _backendResponse({
  String product = 'Recycling Truck 42107',
  String origin = 'Czech Republic 70%, Hungary 30%',
  String company = 'LEGO',
  String hq = 'Denmark',
  String tax = 'Denmark',
}) {
  return RecognitionResult.fromResponse(
    '$product\n\n'
    'Production origin and headquarters:\n'
    '- Estimated production origin of $product: $origin\n'
    '- Company: $company\n'
    '- Country of the HQ: $hq\n'
    '- Country where the company pays taxes and receives profit: $tax',
  );
}

ProductReport _report({
  String product = 'Recycling Truck 42107',
  String origin = 'Czech Republic 70%, Hungary 30%',
  String company = 'LEGO',
  String hq = 'Denmark',
  String tax = 'Denmark',
}) =>
    _backendResponse(
      product: product,
      origin: origin,
      company: company,
      hq: hq,
      tax: tax,
    ).toReport(imagePath: '/tmp/scan.jpg');

void main() {
  group('fabricated percentages never reach the live result screen', () {
    test('are stripped from a fresh backend response', () {
      final report = _report(origin: 'Czech Republic 70%, Hungary 30%');

      expect(report.manufacturedIn.displayValue, 'Czech Republic, Hungary');
      expect(report.manufacturedIn.displayValue, isNot(contains('%')));
    });

    test('the other shape the same box used to produce', () {
      expect(
        _report(origin: 'Denmark 50%, Czech Republic 25%, Mexico 25%')
            .manufacturedIn
            .displayValue,
        'Denmark, Czech Republic, Mexico',
      );
    });

    test('a response that is only numbers collapses to unknown', () {
      final report = _report(origin: '70%, 30%');
      expect(report.manufacturedIn.provenance, Provenance.unknown);
      expect(report.manufacturedIn.hasValue, isFalse);
    });

    test('a percentage that belongs to the product name survives', () {
      // The strip targets the origin value, not the whole reply, and this is
      // the case that proves it has to. Four of the fifty products in the
      // eval set carry a percentage in their actual name — "Lindt Excellence
      // 85% Cacao", "Carré Frais 0%" — and a blunter rule would rename them.
      final report = _report(
        product: 'Lindt Excellence 85% Cacao',
        origin: 'France 60%, Germany 40%',
      );

      expect(report.productName.displayValue, 'Lindt Excellence 85% Cacao');
      expect(report.manufacturedIn.displayValue, 'France, Germany');
    });
  });

  group('a photo cannot produce a verified claim', () {
    test('no claim on a photo scan is verified', () {
      final report = _report();
      final claims = [
        report.productName,
        report.brand,
        report.registeredIn,
        report.manufacturedIn,
        report.headquarters,
        report.taxJurisdiction!,
      ];

      expect(
        claims.map((c) => c.provenance),
        everyElement(isNot(Provenance.verified)),
      );
      expect(report.hasVerifiedClaim, isFalse);
    });

    test('recognised fields are estimated and attributed to the image', () {
      final report = _report();

      expect(report.productName.provenance, Provenance.estimated);
      expect(report.productName.value, 'Recycling Truck 42107');
      expect(report.productName.source, 'Image recognition');
      expect(report.brand.value, 'LEGO');
    });

    test('claims derived from the brand say what they rest on', () {
      final claim = _report().headquarters;

      expect(claim.provenance, Provenance.estimated);
      expect(claim.value, 'Denmark');
      expect(claim.source, contains('recognised from a photo'));
    });

    test('registeredIn is unknown and points at the barcode', () {
      final claim = _report().registeredIn;

      expect(claim.provenance, Provenance.unknown);
      expect(claim.caveat, contains('Scan the barcode'));
    });
  });

  group("the backend's stand-ins for an answer", () {
    test('"Not identified" is not rendered as a finding', () {
      final report = _report(
        product: 'Not identified',
        origin: 'Not identified',
        company: 'Not identified',
        hq: 'Not identified',
        tax: 'Not identified',
      );

      expect(report.productName.provenance, Provenance.unknown);
      expect(report.brand.provenance, Provenance.unknown);
      expect(report.manufacturedIn.provenance, Provenance.unknown);
      expect(report.headquarters.provenance, Provenance.unknown);
      // Unknown rather than absent: the photo pipeline does ask the model
      // about tax residency, so "we asked and got nothing" is the accurate
      // reading. A barcode lookup never asks, and drops the row instead —
      // see report_from_barcode_test.
      expect(report.taxJurisdiction?.provenance, Provenance.unknown);
    });

    test('an undisclosed origin still explains itself', () {
      final claim = _report(origin: 'Not identified').manufacturedIn;

      expect(claim.provenance, Provenance.unknown);
      expect(claim.caveat, contains('never disclosed'));
    });
  });

  group('the scan is attributed to its photo', () {
    test('source is the photo, and the barcode header is not shown', () {
      final report = _report();

      expect(report.source, ScanSource.photo);
      expect(report.imagePath, '/tmp/scan.jpg');
      expect(report.barcode, isNull);
    });
  });
}
