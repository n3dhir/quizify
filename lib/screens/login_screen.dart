import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quizify/router.dart';
import '../providers/auth_provider.dart' as QuizifyAuthProvider;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final authProvider = Provider.of<QuizifyAuthProvider.AuthProvider>(context, listen: false);
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();

  final TextEditingController _passwordController = TextEditingController();

  void _login() async {
    if (_formKey.currentState!.validate()) {
      try {
        // handle login logic
        debugPrint('Email: ${_emailController.text}');
        debugPrint('Password: ${_passwordController.text}');
        await authProvider.login(_emailController.text, _passwordController.text); // Log the user in
      } on FirebaseAuthException catch (e) {
        var errorMessage = "Login failed. Please try again later.";
        if (e.code == 'invalid-credential') {
          errorMessage = "Login failed. Please check your credentials.";
        } else if (e.code == 'network-request-failed') {
          errorMessage =
          "No internet connection. Please check your network settings.";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
        content: Text(
          errorMessage,
          style: TextStyle(color: Theme.of(context).colorScheme.onError),
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        debugPrint('Login error: $e');
      } catch (e) {
        // Catch any other unexpected errors
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'An unexpected error occurred. Please try again later.',
              style: TextStyle(color: Theme.of(context).colorScheme.onError),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        debugPrint('Unexpected error: $e');
      }
    }
  }

String? _validateEmail(String? value) {
  if (value == null || value.isEmpty) {
    return 'Please enter your email';
  }

  final emailRegex = RegExp(
    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
  );

  if (!emailRegex.hasMatch(value)) {
    return 'Please enter a valid email address';
  }

  return null;
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      // appBar: AppBar(title: Text('Login')),
      body: Center(
        // child: FilledButton(
        //   child: Text('Login'),
        //   onPressed: () async {
        //     await authProvider.login(); // Log the user in
        //   },
        // ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: () {
          router.go('/quiz/join'); // 👈 navigate to your join quiz route
        },
        icon: const Icon(Icons.arrow_forward),
        label: const Text("Join a Quiz"),
        style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    ),
                Text(
                  'Sign In',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Welcome back! Please login to your account.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _emailController,
                  obscureText: false,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: WidgetStateTextStyle.resolveWith((
                      Set<WidgetState> states,
                    ) {
                      final Color color =
                          states.contains(WidgetState.error)
                              ? Colors.red.shade300
                              : Colors.grey.shade500;
                      return TextStyle(color: color, letterSpacing: 1.3);
                    }),
                    border: OutlineInputBorder(),
                    errorStyle: TextStyle(color: Colors.red.shade300),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey.shade400),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.deepPurple.shade400),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red.shade300),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.red.shade400,
                        width: 2,
                      ),
                    ),
                  ),
                  validator: _validateEmail,
                ),

                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: WidgetStateTextStyle.resolveWith((
                      Set<WidgetState> states,
                    ) {
                      final Color color =
                          states.contains(WidgetState.error)
                              ? Colors.red.shade300
                              : Colors.grey.shade500;
                      return TextStyle(color: color, letterSpacing: 1.3);
                    }),
                    border: OutlineInputBorder(),
                    errorStyle: TextStyle(color: Colors.red.shade300),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey.shade400),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.deepPurple.shade400),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red.shade300),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.red.shade400,
                        width: 2,
                      ),
                    ),
                  ),
                  validator:
                      (value) =>
                          value!.isEmpty ? 'Please enter your password' : null,
                ),

                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      _login();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 24,
                      ),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(
                          Radius.circular(4),
                        ), // 👈 makes it rectangular
                      ),
                    ),
                    child: const Text(
                      'Login',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

    Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        const Text("Don't have an account? "),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () {
              // Navigate to sign-up page
              router.go('/auth/signup');
            },
            child: Text(
              'Sign up',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
