/// How much a single displayed claim can actually be trusted.
///
/// This exists because the app makes claims about supply chains, and supply
/// chains are mostly opaque. A barcode prefix is a fact. A language model's
/// guess about where a toy was assembled is not, and earlier builds presented
/// both in the same typeface — the same LEGO box produced "Czech Republic 70%,
/// Hungary 30%" on one run and "Denmark 50%, Czech Republic 25%, Mexico 25%" on
/// the next. Numbers that change between runs are not data.
///
/// Every value the UI renders now carries one of these, and the badge is not
/// optional: [ProvenanceClaim] cannot be constructed without one.
enum Provenance {
  /// Derived deterministically from the barcode itself, or read from a
  /// third-party database that cites its own source. Reproducible.
  verified,

  /// A model's inference. Shown as words, never as a percentage — false
  /// precision is worse than an honest shrug.
  estimated,

  /// Nobody involved actually knows. Displayed as such, rather than filled in
  /// with something plausible.
  unknown,
}

extension ProvenanceDisplay on Provenance {
  String get label => switch (this) {
        Provenance.verified => 'Verified',
        Provenance.estimated => 'Estimated',
        Provenance.unknown => 'Unknown',
      };

  /// Shown in the disclosure sheet, so the user can judge the claim themselves
  /// rather than taking the badge on faith.
  String get explanation => switch (this) {
        Provenance.verified =>
          'Derived from the barcode or from a database that cites its source. '
              'Scanning the same product again gives the same answer.',
        Provenance.estimated =>
          'An AI inference, not a record. It may be wrong, and it may differ '
              'between scans. Treat it as a hint, not a fact.',
        Provenance.unknown =>
          'This information is not publicly disclosed. Rather than guess, the '
              'app says so.',
      };
}

/// A single fact on the result screen, bound to where it came from.
class ProvenanceClaim {
  const ProvenanceClaim({
    required this.value,
    required this.provenance,
    this.source,
    this.caveat,
  });

  /// A claim nobody can answer. Kept as a named constructor so "we don't know"
  /// is as easy to express as a real answer — the path of least resistance has
  /// to lead somewhere honest.
  const ProvenanceClaim.unknown({this.caveat})
      : value = null,
        provenance = Provenance.unknown,
        source = null;

  /// The text to display. Null means genuinely absent.
  final String? value;

  final Provenance provenance;

  /// Attribution shown under the value, e.g. 'GS1 prefix 570' or
  /// 'Open Food Facts'. Required in spirit for [Provenance.verified]: a claim
  /// that says "verified" without saying by what is just a nicer-looking guess.
  final String? source;

  /// A correction to the reading a user would otherwise make. The barcode
  /// country is the standing example — almost everyone reads it as "made in".
  final String? caveat;

  bool get hasValue => value != null && value!.trim().isNotEmpty;

  String get displayValue => hasValue ? value!.trim() : 'Not disclosed';
}
