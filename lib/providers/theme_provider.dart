import 'package:flutter/material.dart';
import 'package:quizify/themes/light_mode.dart';
import 'package:quizify/themes/dark_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  static final ThemeProvider _instance = ThemeProvider._internal();

  factory ThemeProvider() => _instance;

  ThemeProvider._internal();

  ThemeData _themeData = lightTheme;
  bool _isDarkMode = false;

  ThemeData get themeData => _themeData;
  bool get isDarkMode => _themeData == darkTheme;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('_is_dark_mode') ?? false;
    _themeData = _isDarkMode ? darkTheme : lightTheme;
  }

  set themeData(ThemeData themeData) {
    _themeData = themeData;
    _saveTheme(themeData == darkTheme);
    notifyListeners();
  }

  void toggleTheme() {
    _themeData = isDarkMode ? lightTheme : darkTheme;
    _saveTheme(themeData == darkTheme);
    notifyListeners();
  }

  Future<void> _saveTheme(bool isDarkMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('_is_dark_mode', isDarkMode);
  }
}
