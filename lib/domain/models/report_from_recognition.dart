import '../claim_text.dart';
import '../provenance.dart';
import 'product_report.dart';
import 'recognition_result.dart';

/// Adapts a live cloud-recognition response to the provenance-aware
/// [ProductReport].
///
/// This adapter is the thing that was missing. [ProductReport] and its badges
/// existed, but only the *stored* records were routed through them — a fresh
/// scan went straight to a screen that printed the backend's strings verbatim,
/// percentages and all. So the app shipped the fix and kept the bug: history
/// showed "Czech Republic, Hungary" while the scan that produced that row had
/// shown "Czech Republic 70%, Hungary 30%" a moment earlier.
///
/// The rule that decides every mapping below: **a photo cannot produce a
/// verified claim.** Nothing here is reproducible. The model may return a
/// different brand for the same box on the next scan, and every field
/// downstream of the brand inherits that. So the ceiling for this whole path
/// is [Provenance.estimated], and the only way to raise it is to scan the
/// barcode — which is what [ProductReport.fromBarcode] is for, and what the
/// caveat on [_noBarcode] tells the user.
extension RecognitionResultReport on RecognitionResult {
  /// [imagePath] is the photo the reading came from. It is required rather
  /// than optional because a recognition result without its photo has no
  /// business being on this screen: [ProductReport.source] would resolve to
  /// [ScanSource.none] and the user would be shown claims with nothing to
  /// attribute them to.
  ProductReport toReport({required String imagePath}) {
    final origin = stripFabricatedPercentages(productionOrigin);

    return ProductReport(
      imagePath: imagePath,
      productName: _recognised(productName),
      brand: _recognised(companyName),
      registeredIn: _noBarcode,
      manufacturedIn: isPlaceholderClaim(origin)
          ? const ProvenanceClaim.unknown(
              caveat: 'Manufacturing location is almost never disclosed '
                  'per item. The app says so rather than filling it in.',
            )
          : ProvenanceClaim(
              value: origin,
              provenance: Provenance.estimated,
              source: 'AI inference from the photo',
              caveat: 'A guess about where these goods were made, not a '
                  'record. It may differ on the next scan.',
            ),
      headquarters: _derivedFromBrand(hqCountry),
      taxJurisdiction: _derivedFromBrand(taxCountry),
    );
  }
}

/// What the model read off the packaging. Estimated, always — the badge is the
/// only thing standing between "the model thinks this is a LEGO box" and "this
/// is a LEGO box".
ProvenanceClaim _recognised(String? value) {
  if (isPlaceholderClaim(value)) return const ProvenanceClaim.unknown();
  return ProvenanceClaim(
    value: value!.trim(),
    provenance: Provenance.estimated,
    source: 'Image recognition',
  );
}

/// A claim that rests on the recognised brand rather than on the image.
///
/// Kept separate from [_recognised] purely so the attribution line says so. A
/// user who sees "Denmark" under Headquarters deserves to know that the answer
/// depends on the model having read the logo correctly — if it saw the wrong
/// brand, this country is wrong too, and it is wrong silently.
ProvenanceClaim _derivedFromBrand(String? value) {
  if (isPlaceholderClaim(value)) return const ProvenanceClaim.unknown();
  return ProvenanceClaim(
    value: value!.trim(),
    provenance: Provenance.estimated,
    source: 'Derived from a brand that was itself only recognised from a photo',
  );
}

/// The registry reading a photo scan cannot produce, phrased as an offer
/// rather than a dead end: there *is* a reproducible answer available, and it
/// takes one more scan to get it.
const ProvenanceClaim _noBarcode = ProvenanceClaim.unknown(
  caveat: 'No barcode was scanned. Scan the barcode on the packaging to get a '
      'reproducible answer instead of a guess.',
);
