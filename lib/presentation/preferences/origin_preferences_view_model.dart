import 'package:flutter/foundation.dart';
import '../../core/config/origin_preferences.dart';

class OriginPreferencesViewModel extends ChangeNotifier {
  List<String> _aligned = List.from(OriginPreferences.defaultAlignedCountries);
  List<String> _lessAligned = [];

  List<String> get aligned => List.unmodifiable(_aligned);
  List<String> get lessAligned => List.unmodifiable(_lessAligned);

  Future<void> addAligned(String country) async {
    final normalized = OriginPreferences.normalize(country);
    if (normalized.isEmpty) return;
    _aligned = _mergeCountry(_aligned, country);
    _lessAligned = _removeNormalized(_lessAligned, normalized);
    notifyListeners();
  }

  Future<void> addLessAligned(String country) async {
    final normalized = OriginPreferences.normalize(country);
    if (normalized.isEmpty) return;
    _lessAligned = _mergeCountry(_lessAligned, country);
    _aligned = _removeNormalized(_aligned, normalized);
    notifyListeners();
  }

  Future<void> removeAligned(String country) async {
    final normalized = OriginPreferences.normalize(country);
    _aligned = _removeNormalized(_aligned, normalized);
    notifyListeners();
  }

  Future<void> removeLessAligned(String country) async {
    final normalized = OriginPreferences.normalize(country);
    _lessAligned = _removeNormalized(_lessAligned, normalized);
    notifyListeners();
  }

  bool matchesAligned(String? text) {
    if (text == null || text.trim().isEmpty) return false;
    final normalized = text.toLowerCase();
    return _aligned.any((country) =>
        normalized.contains(OriginPreferences.normalize(country)));
  }

  bool matchesLessAligned(String? text) {
    if (text == null || text.trim().isEmpty) return false;
    final normalized = text.toLowerCase();
    return _lessAligned.any((country) =>
        normalized.contains(OriginPreferences.normalize(country)));
  }

  List<String> _mergeCountry(List<String> current, String country) {
    final normalized = OriginPreferences.normalize(country);
    final without = _removeNormalized(current, normalized);
    return [country, ...without];
  }

  List<String> _removeNormalized(List<String> current, String normalized) {
    return current
        .where((item) => OriginPreferences.normalize(item) != normalized)
        .toList();
  }
}
