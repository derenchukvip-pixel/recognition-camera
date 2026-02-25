import 'dart:convert';

class RecognitionResult {
  final String message;
  final String rawResponse;
  final String? productName;
  final String? productionOrigin;
  final String? hqCountry;
  final String? taxCountry;

  const RecognitionResult({
    required this.message,
    required this.rawResponse,
    this.productName,
    this.productionOrigin,
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
    final String? product = lines.isNotEmpty ? lines.first : null;

    String? production;
    String? hq;
    String? tax;

    for (final line in lines) {
      final productionMatch = RegExp(
        r'Estimated production origin.*?:\s*(.+)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (productionMatch != null) {
        production = productionMatch.group(1)?.trim();
        continue;
      }
      final hqMatch = RegExp(
        r'Country of the HQ:\s*(.+)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (hqMatch != null) {
        hq = hqMatch.group(1)?.trim();
        continue;
      }
      final taxMatch = RegExp(
        r'Country where the company pays taxes and receives profit:\s*(.+)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (taxMatch != null) {
        tax = taxMatch.group(1)?.trim();
      }
    }

    return _ParsedFields(
      productName: product,
      productionOrigin: production,
      hqCountry: hq,
      taxCountry: tax,
    );
  }
}

class _ParsedFields {
  const _ParsedFields({
    this.productName,
    this.productionOrigin,
    this.hqCountry,
    this.taxCountry,
  });

  final String? productName;
  final String? productionOrigin;
  final String? hqCountry;
  final String? taxCountry;
}
