import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quizify/router.dart';
import '../providers/auth_provider.dart' as QuizifyAuthProvider;
import 'package:lottie/lottie.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late final authProvider =
      Provider.of<QuizifyAuthProvider.AuthProvider>(context, listen: false);
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  late AnimationController _controller;
  bool _isObscureText = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      
      try {
        await authProvider.login(
            _emailController.text, _passwordController.text);
      } on FirebaseAuthException catch (e) {
        var errorMessage = "Login failed. Please try again later.";
        if (e.code == 'invalid-credential') {
          errorMessage = "Login failed. Please check your credentials.";
        } else if (e.code == 'network-request-failed') {
          errorMessage =
              "No internet connection. Please check your network settings.";
        }
        _showErrorSnackBar(errorMessage);
        debugPrint('Login error: $e');
      } catch (e) {
        _showErrorSnackBar('An unexpected error occurred. Please try again later.');
        debugPrint('Unexpected error: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: Theme.of(context).colorScheme.onError),
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
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
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            // Background with quiz pattern
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  image: DecorationImage(
                    image: const AssetImage('assets/images/quiz_pattern.png'),
                    opacity: 0.05,
                    repeat: ImageRepeat.repeat,
                    colorFilter: ColorFilter.mode(
                      Theme.of(context).colorScheme.primary.withOpacity(0.15),
                      BlendMode.srcOver,
                    ),
                  ),
                ),
              ),
            ),
            
            Center(
              child: SingleChildScrollView(
                child: Container(
                  width: isSmallScreen ? size.width * 0.9 : 450,
                  padding: const EdgeInsets.all(24),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Quick join button
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () {
                            router.go('/quiz/join');
                          },
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text("Quick Join Quiz"),
                          style: TextButton.styleFrom(
                            foregroundColor: Theme.of(context).colorScheme.primary,
                            textStyle: const TextStyle(fontWeight: FontWeight.bold),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                              ),
                            ),
                          ),
                        ),
                      ).animate(controller: _controller).slideX(
                        begin: 0.5, 
                        end: 0,
                        duration: 800.ms,
                        curve: Curves.easeOutQuad,
                      ).fadeIn(duration: 800.ms),
                      
                      // Quiz animation
                      SizedBox(
                        height: 160,
                        child: Lottie.network(
                          'https://assets3.lottiefiles.com/packages/lf20_twijbubv.json',
                          controller: _controller,
                          onLoaded: (composition) {
                            _controller.duration = composition.duration;
                            _controller.forward();
                          },
                        ),
                      ).animate().fadeIn(duration: 800.ms),
                      
                      // Animated title
                      DefaultTextStyle(
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        child: AnimatedTextKit(
                          animatedTexts: [
                            TypewriterAnimatedText(
                              'Welcome Back!',
                              speed: const Duration(milliseconds: 100),
                            ),
                          ],
                          totalRepeatCount: 1,
                          displayFullTextOnTap: true,
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      Text(
                        'Log in to continue your quiz journey',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Form
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Email field
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(
                                  Icons.email_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                filled: true,
                                fillColor: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Theme.of(context).colorScheme.primary,
                                    width: 2,
                                  ),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Theme.of(context).colorScheme.error,
                                    width: 2,
                                  ),
                                ),
                                labelStyle: TextStyle(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
                                ),
                              ),
                              validator: _validateEmail,
                            ).animate(controller: _controller).slideY(
                              begin: 0.3, 
                              end: 0,
                              delay: 200.ms,
                              duration: 600.ms,
                              curve: Curves.easeOutQuad,
                            ).fadeIn(delay: 200.ms, duration: 600.ms),
                            
                            const SizedBox(height: 16),
                            
                            // Password field
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _isObscureText,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: Icon(
                                  Icons.lock_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isObscureText ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isObscureText = !_isObscureText;
                                    });
                                  },
                                ),
                                filled: true,
                                fillColor: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Theme.of(context).colorScheme.primary,
                                    width: 2,
                                  ),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Theme.of(context).colorScheme.error,
                                    width: 2,
                                  ),
                                ),
                                labelStyle: TextStyle(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
                                ),
                              ),
                              validator: (value) => value!.isEmpty ? 'Please enter your password' : null,
                            ).animate(controller: _controller).slideY(
                              begin: 0.3, 
                              end: 0,
                              delay: 400.ms,
                              duration: 600.ms,
                              curve: Curves.easeOutQuad,
                            ).fadeIn(delay: 400.ms, duration: 600.ms),
                            
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  // Handle forgot password
                                  // To be implemented
                                },
                                child: Text(
                                  'Forgot Password?',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                            ).animate(controller: _controller).slideY(
                              begin: 0.3, 
                              end: 0,
                              delay: 500.ms,
                              duration: 600.ms,
                              curve: Curves.easeOutQuad,
                            ).fadeIn(delay: 500.ms, duration: 600.ms),
                            
                            const SizedBox(height: 24),
                            
                            // Login button
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                  shadowColor: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                                  elevation: 8,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: _isLoading
                                    ? SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Theme.of(context).colorScheme.onPrimary,
                                        ),
                                      )
                                    : const Text(
                                        'LOGIN',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                              ),
                            ).animate(controller: _controller).slideY(
                              begin: 0.3, 
                              end: 0,
                              delay: 600.ms,
                              duration: 600.ms,
                              curve: Curves.easeOutQuad,
                            ).fadeIn(delay: 600.ms, duration: 600.ms),
                            
                            const SizedBox(height: 24),
                            
                            // Sign up link
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Don't have an account? ",
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                  ),
                                ),
                                MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: () {
                                      router.go('/auth/signup');
                                    },
                                    child: Text(
                                      'Sign Up',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ).animate(controller: _controller).slideY(
                              begin: 0.3, 
                              end: 0,
                              delay: 700.ms,
                              duration: 600.ms,
                              curve: Curves.easeOutQuad,
                            ).fadeIn(delay: 700.ms, duration: 600.ms),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}