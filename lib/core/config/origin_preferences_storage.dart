import 'package:shared_preferences/shared_preferences.dart';

class OriginPreferencesState {
  const OriginPreferencesState({
    required this.aligned,
    required this.lessAligned,
  });

  final List<String> aligned;
  final List<String> lessAligned;
}

class OriginPreferencesStorage {
  static const String _alignedKey = 'originPreferencesAligned';
  static const String _lessAlignedKey = 'originPreferencesLessAligned';

  Future<OriginPreferencesState?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final aligned = prefs.getStringList(_alignedKey);
    final lessAligned = prefs.getStringList(_lessAlignedKey);
    if (aligned == null && lessAligned == null) {
      return null;
    }
    return OriginPreferencesState(
      aligned: aligned ?? <String>[],
      lessAligned: lessAligned ?? <String>[],
    );
  }

  Future<void> save({
    required List<String> aligned,
    required List<String> lessAligned,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_alignedKey, aligned);
    await prefs.setStringList(_lessAlignedKey, lessAligned);
  }
}
