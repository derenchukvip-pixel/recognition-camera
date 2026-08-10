/// Text cleaning shared by every adapter that turns a stored or returned
/// string into a [ProvenanceClaim].
///
/// It lives on its own because three different sources — the backend, the
/// legacy history rows, and the saved-products box — all emit the same two
/// kinds of junk, and each of them used to handle it slightly differently.
/// One implementation, one set of tests.
library;

/// Strings the backend and the older on-device pipeline emit in place of an
/// answer. They are not findings and must not be rendered as values: showing
/// "Unknown company" in the same slot as "LEGO" makes a non-answer look like
/// a result.
const Set<String> _placeholders = {
  'not identified',
  'unknown company',
  'unknown',
  'not available',
  'n/a',
  '-',
  '—',
};

/// True when [value] is absent or one of the backend's stand-ins for "no
/// answer".
bool isPlaceholderClaim(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return true;
  return _placeholders.contains(trimmed.toLowerCase());
}

/// Removes `x70%`, `70 %`, and bare `70%` from an origin string, leaving the
/// country names and tidying the punctuation that held them together.
///
/// The numbers are the whole reason this function exists. The backend prompt
/// used to require them ("Always include percentages"), and the model obliged
/// by inventing different ones for the same box on consecutive scans —
/// "Czech Republic 70%, Hungary 30%" one run, "Denmark 50%, Czech Republic
/// 25%, Mexico 25%" the next. The prompt no longer asks for them, but records
/// written before that change are still on disk and still come back from the
/// server's cache, so the digits get stripped on the way to the screen too.
///
/// Returns null when nothing but numbers was there to begin with.
String? stripFabricatedPercentages(String? value) {
  if (value == null) return null;
  var out = value.replaceAll(RegExp(r'\s*x?\s*\d+(?:[.,]\d+)?\s*%'), '');
  out = out
      .replaceAll(RegExp(r'\s*,\s*,+'), ',')
      .replaceAll(RegExp(r'^[\s,;]+|[\s,;]+$'), '')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
  return out.isEmpty ? null : out;
}
