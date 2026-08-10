import 'dart:convert';

class RecognitionResult {
  final String message;
  final String rawResponse;
  final String? productName;
  final String? productionOrigin;
  final String? companyName;
  final String? hqCountry;
  final String? taxCountry;

  const RecognitionResult({
    required this.message,
    required this.rawResponse,
    this.productName,
    this.productionOrigin,
    this.companyName,
    this.hqCountry,
    this.taxCountry,
  });

  factory RecognitionResult.fromResponse(String body, {String? rawResponse}) {
    final parsed = _parseStructuredFields(body);
    try {
      final decoded = json.decode(body);
      if (decoded is Map<String, dynamic>) {
        final result = decoded['result']?.toString() ?? body;
        final parsedFromResult = _parseStructuredFields(result);
        return RecognitionResult(
          message: result,
          rawResponse: rawResponse ?? body,
          productName: parsedFromResult.productName,
          productionOrigin: parsedFromResult.productionOrigin,
          companyName: parsedFromResult.companyName ??
              _inferCompanyFromProduct(parsedFromResult.productName),
          hqCountry: parsedFromResult.hqCountry,
          taxCountry: parsedFromResult.taxCountry,
        );
      }
    } catch (_) {
      // ignore parsing errors
    }
    return RecognitionResult(
      message: body,
      rawResponse: rawResponse ?? body,
      productName: parsed.productName,
      productionOrigin: parsed.productionOrigin,
      companyName:
          parsed.companyName ?? _inferCompanyFromProduct(parsed.productName),
      hqCountry: parsed.hqCountry,
      taxCountry: parsed.taxCountry,
    );
  }

  static _ParsedFields _parseStructuredFields(String text) {
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final String? product = _extractProductCandidate(lines);

  String? production;
  String? hq;
  String? tax;
  String? company;
  String? productionProduct;

    for (final line in lines) {
      final productionMatch = RegExp(
        r'^\s*-?\s*Estimated production origin.*?:\s*(.+)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (productionMatch != null) {
        production = _normalizeCountryText(
          _cleanLine(productionMatch.group(1)?.trim()),
        );
        final productionProductMatch = RegExp(
          r'^\s*-?\s*Estimated production origin\s+of\s+(.+?)\s*:',
          caseSensitive: false,
        ).firstMatch(line);
        if (productionProductMatch != null) {
          productionProduct = _cleanLine(productionProductMatch.group(1));
        }
        continue;
      }
      final companyMatch = RegExp(
        r'^\s*-?\s*(Company name|Company|Company Name|Brand|Manufacturer)\s*:\s*(.+)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (companyMatch != null) {
        company = _cleanLine(companyMatch.group(2)?.trim());
        continue;
      }
      final hqMatch = RegExp(
        r'^\s*-?\s*Country of the HQ:\s*(.+)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (hqMatch != null) {
        hq = _normalizeCountryText(_cleanLine(hqMatch.group(1)?.trim()));
        continue;
      }
      final taxMatch = RegExp(
        r'^\s*-?\s*Country where the company pays taxes and receives profit:\s*(.+)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (taxMatch != null) {
        tax = _normalizeCountryText(_cleanLine(taxMatch.group(1)?.trim()));
      }
    }

  final sanitizedProduct =
    _sanitizeProductName(product ?? productionProduct);
  final sanitizedCompany = _sanitizeCompanyName(company) ??
    _sanitizeCompanyName(_stripProductSuffix(productionProduct));
    if (sanitizedProduct == null) {
      return const _ParsedFields(
        productName: null,
        productionOrigin: null,
        companyName: null,
        hqCountry: null,
        taxCountry: null,
      );
    }
    return _ParsedFields(
      productName: sanitizedProduct,
      productionOrigin: production,
      companyName: sanitizedCompany,
      hqCountry: hq,
      taxCountry: tax,
    );
  }

  static String? _inferCompanyFromProduct(String? productName) {
    if (_isInvalidText(productName)) return null;
    if (productName == null) return null;
    final trimmed = productName.trim();
    if (trimmed.isEmpty) return null;
    final token = trimmed.split(RegExp(r'\s+')).first;
    if (token.length < 2) return null;
    if (RegExp(r'^\d+$').hasMatch(token)) return null;
    return token;
  }

  static String? _sanitizeProductName(String? value) {
    if (_isInvalidText(value)) return null;
    final trimmed = _cleanLine(value?.trim());
    if (trimmed == null || trimmed.isEmpty) return null;
    if (_isPlaceholder(trimmed)) return null;
    if (_isInvalidProductLine(trimmed)) return null;
    return trimmed;
  }

  static String? _sanitizeCompanyName(String? value) {
    if (_isInvalidText(value)) return null;
    final trimmed = _cleanLine(value?.trim());
    if (trimmed == null || trimmed.isEmpty) return null;
    if (_isPlaceholder(trimmed)) return null;
    return trimmed;
  }

  static String? _extractProductCandidate(List<String> lines) {
    for (final line in lines) {
      final cleaned = _cleanLine(line);
      if (_isInvalidText(cleaned)) {
        continue;
      }
      if (cleaned == null || _isPlaceholder(cleaned)) {
        continue;
      }
      final normalized = cleaned.toLowerCase();
      if (_isInvalidProductLine(normalized) ||
          normalized.startsWith('production origin and headquarters') ||
          normalized.startsWith('production origin') ||
          normalized.startsWith('estimated production origin') ||
          normalized.startsWith('company name') ||
          normalized.startsWith('country of the hq') ||
          normalized.startsWith('country where')) {
        continue;
      }
      return cleaned;
    }
    return null;
  }

  /// A field label, whichever of the backend's keys it uses.
  ///
  /// Matched on the colon rather than on the word: "Brand: LU" is a label,
  /// "Brand X Cereal" is a product. Without the colon this would swallow
  /// every product whose name happens to start with one of these words.
  static final RegExp _labelledField = RegExp(
    r'^(brand owner|brand|company name|company|manufacturer)\s*:',
    caseSensitive: false,
  );

  static bool _isInvalidProductLine(String? value) {
    if (value == null) return true;
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    // The product name is picked as the first line that is not a field, so a
    // label reaching this check would be rendered as the product. It only
    // bites when the model omits the name line — rare, and silent when it
    // happens, which is the combination worth a guard.
    if (_labelledField.hasMatch(normalized)) return true;
    if (normalized.startsWith('estimated production origin')) return true;
    if (normalized.contains('production origin')) return true;
    if (normalized.contains('origin and headquarters')) return true;
    if (normalized.startsWith('country of the hq')) return true;
    if (normalized.startsWith('country where the company pays')) return true;
    return false;
  }

  static String? _normalizeCountryText(String? value) {
    if (value == null) return null;
    return value.replaceAllMapped(
      RegExp(r'\b(USA|US|U\.S\.)\b', caseSensitive: false),
      (_) => 'United States',
    );
  }

  static bool _isInvalidText(String? value) {
    if (value == null) return true;
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return normalized.startsWith("i'm") ||
        normalized.startsWith('i am') ||
        normalized.contains("can't") ||
        normalized.contains('cannot') ||
        normalized.contains('unable') ||
        normalized.contains('sorry');
  }

  static bool _isPlaceholder(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'product name' ||
        normalized == 'product' ||
        normalized == 'company name' ||
        normalized == 'company';
  }

  static String? _cleanLine(String? value) {
    if (value == null) return null;
    var cleaned = value.replaceAll(RegExp(r'^[*#\-\s]+'), '').trim();
    cleaned = cleaned.replaceAll(RegExp(r'[*_`]+'), '').trim();
    return cleaned;
  }

  static String? _stripProductSuffix(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final match = RegExp(r'^(.*?)(?:\s+products?|\s+product)?\s*$',
            caseSensitive: false)
        .firstMatch(trimmed);
    return match?.group(1)?.trim() ?? trimmed;
  }

}

class _ParsedFields {
  const _ParsedFields({
    this.productName,
    this.productionOrigin,
    this.companyName,
    this.hqCountry,
    this.taxCountry,
  });

  final String? productName;
  final String? productionOrigin;
  final String? companyName;
  final String? hqCountry;
  final String? taxCountry;
}
