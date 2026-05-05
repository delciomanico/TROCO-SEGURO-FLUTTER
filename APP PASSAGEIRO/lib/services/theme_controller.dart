import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController {
  static final ThemeController instance = ThemeController._internal();
  ThemeController._internal();

  final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.dark);
  static const _prefKey = 'ts_theme_mode';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString(_prefKey);
    if (mode == 'light') {
      themeMode.value = ThemeMode.light;
    } else {
      themeMode.value = ThemeMode.dark;
    }
  }

  Future<void> setDark(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    themeMode.value = enabled ? ThemeMode.dark : ThemeMode.light;
    await prefs.setString(_prefKey, enabled ? 'dark' : 'light');
  }
}
