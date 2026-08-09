import '../claim_text.dart';
import '../provenance.dart';
import 'history_item.dart';
import 'product_report.dart';
import 'saved_product.dart';

/// Adapts the two stored record types — [HistoryItem] and [SavedProduct] — to
/// the provenance-aware [ProductReport].
///
/// Both were written by an earlier version that recorded free text with no
/// notion of where a value came from, so **nothing** recovered from them can be
/// marked verified: the information needed to justify that badge was never
/// stored. Everything becomes [Provenance.estimated] at best.
///
/// The percentages are the sharp edge. Old rows contain strings like
/// `"Czech Republic x70%, Hungary x30%"` produced by a model that returned
/// different numbers for the same box on consecutive scans. Rendering them
/// as-is would reintroduce exactly the false precision this screen exists to
/// remove, so [stripFabricatedPercentages] keeps the country names and drops
/// the digits.
extension HistoryItemReport on HistoryItem {
  ProductReport toReport() => _legacyReport(
        imagePath: imagePath.isNotEmpty ? imagePath : originalImagePath,
        productName: productName,
        companyName: companyName,
        productionOrigin: productionOrigin,
        hqCountry: hqCountry,
        taxCountry: taxCountry,
      );
}

extension SavedProductReport on SavedProduct {
  ProductReport toReport() => _legacyReport(
        imagePath: imagePath.isNotEmpty ? imagePath : originalImagePath,
        productName: productName,
        companyName: companyName,
        productionOrigin: productionOrigin,
        hqCountry: hqCountry,
        taxCountry: taxCountry,
      );
}

ProductReport _legacyReport({
  required String imagePath,
  required String productName,
  required String companyName,
  required String? productionOrigin,
  required String? hqCountry,
  required String? taxCountry,
}) {
  final origin = stripFabricatedPercentages(productionOrigin);

  return ProductReport(
    imagePath: imagePath,
    productName: _legacyClaim(productName),
    brand: _legacyClaim(companyName),
    // The old pipeline conflated "where it was made" with whatever the model
    // said; there is no registry reading to recover, so this is unknown rather
    // than back-filled.
    registeredIn: const ProvenanceClaim.unknown(
      caveat: 'Saved before barcode lookup existed. Rescan the barcode for a '
          'reproducible answer.',
    ),
    // `isPlaceholderClaim` runs after the strip, not before: an origin of
    // "Not identified" is a non-answer and must collapse to unknown rather
    // than be rendered as a finding in the same slot as a real country.
    manufacturedIn: isPlaceholderClaim(origin)
        ? const ProvenanceClaim.unknown()
        : ProvenanceClaim(
            value: origin,
            provenance: Provenance.estimated,
            source: 'Recorded by an earlier version',
            caveat: 'This was an AI guess, and the original record included '
                'invented percentages. Only the countries are kept.',
          ),
    headquarters: _legacyClaim(hqCountry),
    // Null when the old row never recorded one, so the screen leaves the row
    // out entirely rather than asserting that the tax jurisdiction is unknown.
    taxJurisdiction:
        isPlaceholderClaim(taxCountry) ? null : _legacyClaim(taxCountry),
  );
}

/// Legacy text: never better than a guess, and placeholder strings from the old
/// pipeline collapse to unknown rather than being shown as findings.
ProvenanceClaim _legacyClaim(String? value) {
  if (isPlaceholderClaim(value)) return const ProvenanceClaim.unknown();
  return ProvenanceClaim(
    value: value!.trim(),
    provenance: Provenance.estimated,
    source: 'Recorded by an earlier version',
  );
}
