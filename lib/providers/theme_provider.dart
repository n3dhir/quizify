import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quizify/themes/light_mode.dart';
import 'package:quizify/themes/dark_mode.dart';

class ThemeProvider with ChangeNotifier {
  static const _prefKey = '_is_dark_mode';
  bool _isDarkMode = false;

  // Expose current mode as getters
  ThemeData get lightTheme => lightThemeData;
  ThemeData get darkTheme => darkThemeData;
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;
  bool get isDarkMode => _isDarkMode;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_prefKey) ?? false;
    notifyListeners();
  }

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    SharedPreferences.getInstance()
        .then((p) => p.setBool(_prefKey, _isDarkMode));
    notifyListeners();
  }
}