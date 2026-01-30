import 'dart:convert';

class RecognitionResult {
  final String message;
  final String rawResponse;

  const RecognitionResult({
    required this.message,
    required this.rawResponse,
  });

  factory RecognitionResult.fromResponse(String body) {
    try {
      final decoded = json.decode(body);
      if (decoded is Map<String, dynamic>) {
        final result = decoded['result']?.toString() ?? body;
        return RecognitionResult(message: result, rawResponse: body);
      }
    } catch (_) {
      // ignore parsing errors
    }
    return RecognitionResult(message: body, rawResponse: body);
  }
}
