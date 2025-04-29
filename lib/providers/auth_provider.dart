import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthProvider with ChangeNotifier {
  static final AuthProvider _instance = AuthProvider._internal();

  factory AuthProvider() {
    return _instance;
  }

  AuthProvider._internal() {
    // Set up Firebase Auth state listener immediately
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      _isLoggedIn = user != null && !user.isAnonymous;
      _isLoading = false;
      notifyListeners();
    });
  }

  bool _isLoggedIn = false;
  bool _isLoading = true;

  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;

  // The rest of your methods remain similar, but without the SharedPreferences logic
  Future<void> login(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();

      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      // No need to set SharedPreferences - the auth listener will handle state
    } catch (e) {
      print('Login failed: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Similarly for signup method
  Future<void> signup(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();

      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      if (userCredential.user != null) {
        CollectionReference users =
            FirebaseFirestore.instance.collection('users');
        await users.doc(userCredential.user?.uid).set({
          'email': userCredential.user?.email,
          'createdAt': FieldValue.serverTimestamp(),
        });
        // Auth state listener will handle the isLoggedIn flag
      }
    } catch (e) {
      print('Signup failed: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      // Auth state listener will handle the isLoggedIn flag
    } catch (e) {
      print('Logout failed: $e');
      rethrow;
    }
  }
}
