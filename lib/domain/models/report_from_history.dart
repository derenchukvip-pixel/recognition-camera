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
/// remove, so [_stripFabricatedPercentages] keeps the country names and drops
/// the digits.
extension HistoryItemReport on HistoryItem {
  ProductReport toReport() => _legacyReport(
        imagePath: imagePath.isNotEmpty ? imagePath : originalImagePath,
        productName: productName,
        companyName: companyName,
        productionOrigin: productionOrigin,
        hqCountry: hqCountry,
      );
}

extension SavedProductReport on SavedProduct {
  ProductReport toReport() => _legacyReport(
        imagePath: imagePath.isNotEmpty ? imagePath : originalImagePath,
        productName: productName,
        companyName: companyName,
        productionOrigin: productionOrigin,
        hqCountry: hqCountry,
      );
}

ProductReport _legacyReport({
  required String imagePath,
  required String productName,
  required String companyName,
  required String? productionOrigin,
  required String? hqCountry,
}) {
  final origin = _stripFabricatedPercentages(productionOrigin);

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
    manufacturedIn: origin == null
        ? const ProvenanceClaim.unknown()
        : ProvenanceClaim(
            value: origin,
            provenance: Provenance.estimated,
            source: 'Recorded by an earlier version',
            caveat: 'This was an AI guess, and the original record included '
                'invented percentages. Only the countries are kept.',
          ),
    headquarters: _legacyClaim(hqCountry),
  );
}

/// Legacy text: never better than a guess, and placeholder strings from the old
/// pipeline collapse to unknown rather than being shown as findings.
ProvenanceClaim _legacyClaim(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return const ProvenanceClaim.unknown();
  const placeholders = {
    'not identified',
    'unknown company',
    'unknown',
    'n/a',
  };
  if (placeholders.contains(trimmed.toLowerCase())) {
    return const ProvenanceClaim.unknown();
  }
  return ProvenanceClaim(
    value: trimmed,
    provenance: Provenance.estimated,
    source: 'Recorded by an earlier version',
  );
}

/// Removes `x70%`, `70 %`, and bare `70%` from a legacy origin string, leaving
/// the country names and tidying the punctuation that held them together.
///
/// Returns null when nothing but numbers was there to begin with.
String? _stripFabricatedPercentages(String? value) {
  if (value == null) return null;
  var out = value.replaceAll(RegExp(r'\s*x?\s*\d+(?:[.,]\d+)?\s*%'), '');
  out = out
      .replaceAll(RegExp(r'\s*,\s*,+'), ',')
      .replaceAll(RegExp(r'^[\s,;]+|[\s,;]+$'), '')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
  return out.isEmpty ? null : out;
}
