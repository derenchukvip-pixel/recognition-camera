import 'package:shared_preferences/shared_preferences.dart';

class DisclaimerStorage {
  static const String _acceptedKey = 'disclaimerAccepted';

  Future<bool> isAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_acceptedKey) ?? false;
  }

  Future<void> setAccepted(bool accepted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_acceptedKey, accepted);
  }
}
