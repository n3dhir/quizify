import 'package:firebase_auth/firebase_auth.dart';

// FirebaseAuth instance
final FirebaseAuth _auth = FirebaseAuth.instance;

// Sign up a user
Future<User?> signUp(String email, String password) async {
  try {
    UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return userCredential.user;
  } on FirebaseAuthException catch (e) {
    print("Error: ${e.message}");
    return null;
  }
}

// Sign in a user
Future<User?> signIn(String email, String password) async {
  try {
    UserCredential userCredential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return userCredential.user;
  } on FirebaseAuthException catch (e) {
    print("Error: ${e.message}");
    return null;
  }
}
