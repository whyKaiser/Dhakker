import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleController {
  static final ValueNotifier<Locale> locale = ValueNotifier(const Locale('ar'));

  static Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final code = sp.getString('lang') ?? 'ar';
    locale.value = Locale(code);
  }

  static Future<void> toggle() async {
    final newCode = locale.value.languageCode == 'ar' ? 'en' : 'ar';
    locale.value = Locale(newCode);
    final sp = await SharedPreferences.getInstance();
    await sp.setString('lang', newCode);
  }
}
