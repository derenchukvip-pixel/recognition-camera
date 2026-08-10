import 'claim_text.dart';

/// Whether a claim's countries appear on one of the user's own lists.
///
/// This is deliberately not part of [ProvenanceClaim]. A provenance badge says
/// how far a claim can be trusted; this says whether the user asked to be told
/// about it. Two unrelated questions, and folding them into one value is how a
/// preference match ends up looking like a verification.
enum OriginMatch {
  /// No country here is on either list, or there is nothing to match against.
  none,

  /// Every matched country is on the preferred list.
  preferred,

  /// Every matched country is on the avoided list.
  avoided,

  /// Countries from both lists. "Czech Republic, Hungary" where one is on
  /// each — reporting only the first would tell the user half the answer.
  mixed,
}

/// Matches a claim value against the two lists.
///
/// Comparison is **exact after normalising**, per comma-separated part, not a
/// substring test. Substring matching is the obvious implementation and it is
/// wrong in a way that only shows up occasionally: a preference for "China"
/// then matches "Indochina", and one for "Oman" matches "Romania". A false
/// match here puts a mark next to a country the user never asked about, on a
/// screen whose entire purpose is not overstating things.
OriginMatch matchOrigin(
  String? value, {
  required List<String> preferred,
  required List<String> avoided,
}) {
  if (isPlaceholderClaim(value)) return OriginMatch.none;

  final preferredKeys = preferred.map(_normalise).toSet();
  final avoidedKeys = avoided.map(_normalise).toSet();

  var sawPreferred = false;
  var sawAvoided = false;

  for (final part in value!.split(RegExp(r'[,\n;]'))) {
    final key = _normalise(part);
    if (key.isEmpty) continue;
    if (preferredKeys.contains(key)) sawPreferred = true;
    if (avoidedKeys.contains(key)) sawAvoided = true;
  }

  if (sawPreferred && sawAvoided) return OriginMatch.mixed;
  if (sawPreferred) return OriginMatch.preferred;
  if (sawAvoided) return OriginMatch.avoided;
  return OriginMatch.none;
}

String _normalise(String value) => value.trim().toLowerCase();
