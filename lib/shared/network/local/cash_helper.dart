import 'package:shared_preferences/shared_preferences.dart';

class CashHelper {
  static SharedPreferences? preferences;

  static initPreference() async {
    preferences = await SharedPreferences.getInstance();
  }

  static Future<bool?> saveCash({
    required String key,
    required dynamic value,
  }) async {
    if (value is int) {
      return await preferences?.setInt(key, value);
    } else if (value is String) {
      return await preferences?.setString(key, value);
    } else if (value is bool) {
      return await preferences?.setBool(key, value);
    } else {
      return await preferences?.setDouble(key, value);
    }
  }

  static dynamic getCash({
    required String key,
  }) {
    return preferences?.get(key);
  }

  static Future<bool> removeCash({
    required String key,
  }) async {
    return await preferences!.remove(key);
  }
}
