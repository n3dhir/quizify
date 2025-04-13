class AuthService {
  Future<void> login() async {
    // Simulate a login process (e.g., using Firebase or your authentication logic)
    await Future.delayed(Duration(seconds: 2));
    print("Logged in successfully");
  }
}
