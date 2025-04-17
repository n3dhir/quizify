import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  // Method to log in the user using Firebase Authentication
  Future<void> login(String email, String password) async {
    try {
      _isLoading = true;
      

      // Perform Firebase Authentication login
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      if (userCredential.user != null) {
        final prefs = await SharedPreferences.getInstance();
        prefs.setBool('is_logged_in', true);
        _isLoggedIn = true;
        notifyListeners(); // Notify listeners about the loading state
      }
    } catch (e) {
      // Handle login error (e.g., invalid credentials)
      print('Login failed: $e');
      _isLoggedIn = false;
      rethrow; // Rethrow the error to be handled in the UI
    } finally {
      _isLoading = false;
    }
  }
  // Method to sign up the user using Firebase Authentication
  Future<void> signup(String email, String password) async {
    try {
      _isLoading = true;

      // Perform Firebase Authentication signup
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      if (userCredential.user != null) {

        CollectionReference users = FirebaseFirestore.instance.collection('users');
          await users.doc(userCredential.user?.uid).set({
            'email': userCredential.user?.email,
            'createdAt': FieldValue.serverTimestamp(),
          });

        final prefs = await SharedPreferences.getInstance();
        prefs.setBool('is_logged_in', true);
        _isLoggedIn = true;
        notifyListeners(); // Notify listeners about the login state
      }
    } catch (e) {
      // Handle signup error (e.g., email already in use)
      print('Signup failed: $e');
      _isLoggedIn = false;
      rethrow; // Rethrow the error to be handled in the UI
    } finally {
      _isLoading = false;
    }
  }
  // Method to log out the user
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('is_logged_in', false);
    _isLoggedIn = false;
    notifyListeners();  // Notify listeners about the change
  }
}
