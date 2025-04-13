import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {

  static final AuthProvider _instance = AuthProvider._internal();

  factory AuthProvider() {
    return _instance;
  }

  AuthProvider._internal() {
    // _loadLoginStatus(); // optional: load persisted state
    Future.delayed(Duration(milliseconds: 1000), _loadLoginStatus); // optional: load persisted state
  }

  bool _isLoggedIn = false;
  bool _isLoading = true;

  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;

  // Load the saved login status from SharedPreferences
  Future<void> _loadLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getBool('is_logged_in') ?? false;
    _isLoading = false;
    notifyListeners();  // Notify listeners about the change in login state
  }

  // Method to log in the user
  Future<void> login() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('is_logged_in', true);
    _isLoggedIn = true;
    notifyListeners();  // Notify listeners about the change
  }

  // Method to log out the user
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('is_logged_in', false);
    _isLoggedIn = false;
    notifyListeners();  // Notify listeners about the change
  }
}
