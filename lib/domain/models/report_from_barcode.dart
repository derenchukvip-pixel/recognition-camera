import '../claim_text.dart';
import '../provenance.dart';
import 'product_report.dart';

/// Builds the report for a barcode scan.
///
/// This is the path the whole provenance model was designed around, and until
/// now it was unreachable from the running app: the only screen that opened the
/// scanner was not wired into any route, so `ProductReport.fromBarcode` existed
/// solely to feed the web preview's fixtures.
///
/// Two independent sources meet here and they are kept apart on purpose:
///
/// * the **GS1 prefix**, decoded from the digits offline, with the check digit
///   verified first — see [ProductReport.fromBarcode];
/// * the **Open Food Facts record**, when the barcode is in it.
///
/// Both are [Provenance.verified], and both carry a caveat saying what that
/// badge does and does not promise. Verified here means *reproducible and
/// attributed* — scan the same barcode tomorrow and you get the same answer
/// from the same named source. It does not mean the answer is true. Open Food
/// Facts is community-maintained, and the caveat says so rather than leaving
/// the badge to imply an audit that never happened.
ProductReport reportFromBarcode(
  String barcode, {
  Map<String, dynamic>? openFoodFactsProduct,
}) {
  final product = openFoodFactsProduct;

  if (product == null) {
    // Not a failure. The digits still decode, so the registry claim stands on
    // its own and the screen shows exactly the part of the answer that is
    // knowable — which is more honest, and more useful, than an error page.
    return ProductReport(
      barcode: barcode,
      productName: const ProvenanceClaim.unknown(
        caveat: _notInDatabase,
      ),
      brand: const ProvenanceClaim.unknown(caveat: _notInDatabase),
      registeredIn: ProductReport.fromBarcode(barcode),
      manufacturedIn: const ProvenanceClaim.unknown(),
      headquarters: const ProvenanceClaim.unknown(caveat: _noHeadquartersData),
    );
  }

  return ProductReport(
    barcode: barcode,
    productName: _fromDatabase(product['product_name']),
    brand: _fromDatabase(product['brands']),
    registeredIn: ProductReport.fromBarcode(barcode),
    manufacturedIn: _fromDatabase(
      product['manufacturing_places'],
      caveat: 'Declared in the Open Food Facts record by whoever added it, '
          'not by the manufacturer.',
    ),
    headquarters: const ProvenanceClaim.unknown(caveat: _noHeadquartersData),
  );
}

/// A field read straight out of the Open Food Facts record.
///
/// Verified, because the lookup is reproducible and the source is named — but
/// never without the caveat. A crowd-sourced field with a Verified badge and
/// no qualifier is the same overclaim the percentages were, in a nicer font.
ProvenanceClaim _fromDatabase(Object? raw, {String? caveat}) {
  final value = raw is String ? raw.trim() : null;
  if (isPlaceholderClaim(value)) return const ProvenanceClaim.unknown();
  return ProvenanceClaim(
    value: value,
    provenance: Provenance.verified,
    source: 'Open Food Facts',
    caveat: caveat ?? _communityMaintained,
  );
}

const String _communityMaintained =
    'Open Food Facts is community-maintained. The same barcode always returns '
    'this same record, but the record itself was entered by a contributor.';

const String _notInDatabase =
    'This barcode is not in Open Food Facts. The registry country below still '
    'comes from the digits themselves.';

const String _noHeadquartersData =
    'Open Food Facts does not record where a brand owner is headquartered.';
