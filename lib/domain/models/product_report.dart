import '../../data/gs1/gs1_prefixes.dart';
import '../provenance.dart';

/// How the product in front of the user was captured.
enum ScanSource {
  /// A photo was taken and run through the on-device model.
  photo,

  /// A barcode was scanned. No image involved, and the screen must not
  /// pretend otherwise.
  barcode,

  /// Neither — nothing to attribute the reading to.
  none,
}

/// Everything the result screen renders, with each claim bound to its source.
///
/// The screen takes one of these and nothing else — no `File`, no API client,
/// no view model. That is what lets the same widget render a real scan on a
/// phone and a fixture in the web preview, and it is why the design can be
/// reviewed without a camera in the loop.
class ProductReport {
  const ProductReport({
    required this.productName,
    required this.brand,
    required this.registeredIn,
    required this.manufacturedIn,
    required this.headquarters,
    this.taxJurisdiction,
    this.barcode,
    this.imagePath,
  });

  final ProvenanceClaim productName;
  final ProvenanceClaim brand;

  /// Where the brand owner registered with GS1. Carries a caveat, always —
  /// see [fromBarcode].
  final ProvenanceClaim registeredIn;

  /// Where the goods were actually made. Almost never disclosed, and the app
  /// says so rather than inferring it from the barcode.
  final ProvenanceClaim manufacturedIn;

  final ProvenanceClaim headquarters;

  /// Where the brand owner books its profit, when that differs from the
  /// headquarters. Null rather than [ProvenanceClaim.unknown] on purpose: the
  /// two mean different things, and the screen treats them differently.
  /// `unknown` says "we looked and nobody discloses it" and earns a row with
  /// an Unknown badge; null says the reading never covered this at all — a
  /// barcode lookup has nothing to say about tax residency — and earns no row.
  /// Rendering an Unknown badge for a question that was never asked would
  /// overstate how much the app checked.
  final ProvenanceClaim? taxJurisdiction;

  final String? barcode;
  final String? imagePath;

  /// What the user actually pointed at the product.
  ///
  /// This matters more than it looks. A barcode scan and a photo scan produce
  /// completely different claims from completely different places — the barcode
  /// gives a reproducible registry lookup, the photo gives a model's opinion —
  /// and the screen has to say which one happened. An earlier draft rendered an
  /// empty photo frame on a barcode-only scan, which implied the app had looked
  /// at a picture it never had.
  ScanSource get source {
    if (imagePath != null && imagePath!.isNotEmpty) return ScanSource.photo;
    if (barcode != null && barcode!.isNotEmpty) return ScanSource.barcode;
    return ScanSource.none;
  }

  /// Builds the barcode-derived part of a report.
  ///
  /// Three outcomes, and the distinction between them is the point:
  ///
  /// * checksum fails → the scan is unreliable, so nothing gets a Verified
  ///   badge. A misread digit resolves to a different country just as
  ///   confidently as a correct one.
  /// * special-use prefix (ISBN, coupon, in-store) → the prefix encodes a
  ///   scheme, not a member organisation; reporting a country would be wrong.
  /// * otherwise → a real, reproducible answer, attributed to the three digits
  ///   it came from.
  static ProvenanceClaim fromBarcode(String barcode) {
    const caveat =
        'This is where the brand owner registered with GS1 — not where the '
        'product was made. A company registered in one country routinely '
        'manufactures in another.';

    if (!Gs1Lookup.isChecksumValid(barcode)) {
      return const ProvenanceClaim.unknown(
        caveat: 'The barcode failed its check digit, so it may have been '
            'misread. Rescan for a reliable answer.',
      );
    }

    final allocation = Gs1Lookup.lookup(barcode);
    if (allocation == null) {
      return const ProvenanceClaim.unknown(
        caveat: 'This prefix is not allocated to any GS1 member organisation.',
      );
    }

    final prefix = Gs1Lookup.prefixOf(barcode);

    if (allocation.isSpecialUse) {
      return ProvenanceClaim(
        value: allocation.country,
        provenance: Provenance.verified,
        source: 'GS1 prefix $prefix',
        caveat: 'This prefix identifies a numbering scheme rather than a '
            'country, so there is no registering country to report.',
      );
    }

    return ProvenanceClaim(
      value: allocation.country,
      provenance: Provenance.verified,
      source: 'GS1 prefix $prefix',
      caveat: caveat,
    );
  }

  /// Serialised so a stored scan keeps its badges.
  ///
  /// Before this existed, history recorded five loose strings and the badges
  /// were reconstructed by an adapter that could only ever answer "estimated
  /// at best" — the justification for anything stronger had not been kept. A
  /// barcode scan, whose whole value is a reproducible Verified reading, would
  /// have come back from disk downgraded to a guess. That is why the app
  /// refused to save one at all.
  ///
  /// [imagePath] is deliberately absent. The photo lives at a path the storage
  /// layer chose and may later move or be cleaned up by the OS, so the record
  /// owns it and hands it back through [fromJson].
  Map<String, dynamic> toJson() => {
        'version': 1,
        'barcode': barcode,
        'productName': productName.toJson(),
        'brand': brand.toJson(),
        'registeredIn': registeredIn.toJson(),
        'manufacturedIn': manufacturedIn.toJson(),
        'headquarters': headquarters.toJson(),
        'taxJurisdiction': taxJurisdiction?.toJson(),
      };

  factory ProductReport.fromJson(
    Map<String, dynamic> json, {
    String? imagePath,
  }) {
    ProvenanceClaim claim(String key) {
      final raw = json[key];
      if (raw is Map) {
        return ProvenanceClaim.fromJson(Map<String, dynamic>.from(raw));
      }
      return const ProvenanceClaim.unknown();
    }

    final tax = json['taxJurisdiction'];
    return ProductReport(
      barcode: json['barcode'] as String?,
      imagePath: imagePath,
      productName: claim('productName'),
      brand: claim('brand'),
      registeredIn: claim('registeredIn'),
      manufacturedIn: claim('manufacturedIn'),
      headquarters: claim('headquarters'),
      taxJurisdiction: tax is Map
          ? ProvenanceClaim.fromJson(Map<String, dynamic>.from(tax))
          : null,
    );
  }

  /// True when at least one claim is a reproducible fact rather than a guess.
  /// The screen uses this to decide whether to lead with the data or with a
  /// caveat.
  bool get hasVerifiedClaim => [
        productName,
        brand,
        registeredIn,
        manufacturedIn,
        headquarters,
        if (taxJurisdiction != null) taxJurisdiction!,
      ].any((c) => c.provenance == Provenance.verified && c.hasValue);
}
