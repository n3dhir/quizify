import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quizify/router.dart';
import '../providers/auth_provider.dart' as local_auth_provider;
import 'package:lottie/lottie.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with SingleTickerProviderStateMixin {
  late final authProvider = Provider.of<local_auth_provider.AuthProvider>(
    context,
    listen: false,
  );
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  late AnimationController _controller;
  bool _isObscurePassword = true;
  bool _isObscureConfirmPassword = true;
  bool _isLoading = false;
  int _currentStep = 0;

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
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _signup() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        await authProvider.signup(
          _emailController.text,
          _passwordController.text,
        );
      } on FirebaseAuthException catch (e) {
        var errorMessage = "Signup failed. Please try again later.";
        if (e.code == 'email-already-in-use') {
          errorMessage =
              "The email is already registered. Please try logging in.";
        }
        if (e.code == 'network-request-failed') {
          errorMessage =
              "No internet connection. Please check your network settings.";
        }
        _showErrorSnackBar(errorMessage);
        debugPrint('Signup error: $e');
      } catch (e) {
        _showErrorSnackBar(
            'An unexpected error occurred. Please try again later.');
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

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }

    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }

    if (value.length < 6) {
      return 'Password must be at least 6 characters long';
    }

    return null;
  }

  String? _validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your name';
    }
    return null;
  }

  void _nextStep() {
    if (_currentStep == 0) {
      // if name is empty, or email is empty, or our validator returns non-null (i.e. an error),
      // then we bail out and don’t advance.
      if (_nameController.text.isEmpty ||
          _emailController.text.isEmpty ||
          _validateEmail(_emailController.text) != null) {
        return;
      }
    }

    setState(() {
      _currentStep = 1;
    });
  }

  void _previousStep() {
    setState(() {
      _currentStep = 0;
    });
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
            // Background pattern
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
                        color: Theme.of(context)
                            .colorScheme
                            .secondary
                            .withOpacity(0.1),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .secondary
                          .withOpacity(0.1),
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
                            foregroundColor:
                                Theme.of(context).colorScheme.secondary,
                            textStyle:
                                const TextStyle(fontWeight: FontWeight.bold),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: Theme.of(context)
                                    .colorScheme
                                    .secondary
                                    .withOpacity(0.5),
                              ),
                            ),
                          ),
                        ),
                      )
                          .animate(controller: _controller)
                          .slideX(
                            begin: 0.5,
                            end: 0,
                            duration: 800.ms,
                            curve: Curves.easeOutQuad,
                          )
                          .fadeIn(duration: 800.ms),

                      // Quiz animation
                      SizedBox(
                        height: 140,
                        child: Lottie.network(
                          'https://assets1.lottiefiles.com/packages/lf20_rbtawnwz.json', // Different quiz animation
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
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        child: AnimatedTextKit(
                          animatedTexts: [
                            TypewriterAnimatedText(
                              'Join the Quiz Fun!',
                              speed: const Duration(milliseconds: 100),
                            ),
                          ],
                          totalRepeatCount: 1,
                          displayFullTextOnTap: true,
                        ),
                      ),

                      const SizedBox(height: 8),
                      Text(
                        'Create an account to start your quiz adventure',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),

                      // Signup steps indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildStepIndicator(0, 'Info'),
                          _buildStepConnector(),
                          _buildStepIndicator(1, 'Password'),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Form
                      Form(
                        key: _formKey,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          transitionBuilder:
                              (Widget child, Animation<double> animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: _currentStep == 0
                                      ? const Offset(1, 0)
                                      : const Offset(-1, 0),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: _currentStep == 0
                              ? _buildPersonalInfoForm()
                              : _buildPasswordForm(),
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

  Widget _buildStepIndicator(int step, String label) {
    final isActive = _currentStep == step;
    final isCompleted = _currentStep > step;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isActive || isCompleted
                ? Theme.of(context).colorScheme.secondary
                : Theme.of(context).colorScheme.secondary.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive
                  ? Theme.of(context).colorScheme.secondary
                  : Theme.of(context).colorScheme.secondary.withOpacity(0.5),
              width: 2,
            ),
          ),
          child: Center(
            child: isCompleted
                ? Icon(
                    Icons.check,
                    color: Theme.of(context).colorScheme.onSecondary,
                  )
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      color: isActive
                          ? Theme.of(context).colorScheme.onSecondary
                          : Theme.of(context).colorScheme.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isActive || isCompleted
                ? Theme.of(context).colorScheme.secondary
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildStepConnector() {
    return Container(
      width: 60,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: _currentStep > 0
            ? Theme.of(context).colorScheme.secondary
            : Theme.of(context).colorScheme.secondary.withOpacity(0.2),
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }

  Widget _buildPersonalInfoForm() {
    return Column(
      key: const ValueKey('info_form'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name field
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'Full Name',
            prefixIcon: Icon(
              Icons.person_rounded,
              color: Theme.of(context).colorScheme.secondary,
            ),
            filled: true,
            fillColor:
                Theme.of(context).colorScheme.secondary.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.secondary,
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
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.8),
            ),
          ),
          validator: _validateName,
        )
            .animate(controller: _controller)
            .slideY(
              begin: 0.3,
              end: 0,
              delay: 200.ms,
              duration: 600.ms,
              curve: Curves.easeOutQuad,
            )
            .fadeIn(delay: 200.ms, duration: 600.ms),

        const SizedBox(height: 16),

        // Email field
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(
              Icons.email_rounded,
              color: Theme.of(context).colorScheme.secondary,
            ),
            filled: true,
            fillColor:
                Theme.of(context).colorScheme.secondary.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.secondary,
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
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.8),
            ),
          ),
          validator: _validateEmail,
        )
            .animate(controller: _controller)
            .slideY(
              begin: 0.3,
              end: 0,
              delay: 400.ms,
              duration: 600.ms,
              curve: Curves.easeOutQuad,
            )
            .fadeIn(delay: 400.ms, duration: 600.ms),

        const SizedBox(height: 24),

        // Next button
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: _nextStep,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondary,
              foregroundColor: Theme.of(context).colorScheme.onSecondary,
              shadowColor:
                  Theme.of(context).colorScheme.secondary.withOpacity(0.4),
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'NEXT',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
        )
            .animate(controller: _controller)
            .slideY(
              begin: 0.3,
              end: 0,
              delay: 600.ms,
              duration: 600.ms,
              curve: Curves.easeOutQuad,
            )
            .fadeIn(delay: 600.ms, duration: 600.ms),

        const SizedBox(height: 24),

        // Login link
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Already have an account? ",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  router.go('/auth/login');
                },
                child: Text(
                  'Login',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        )
            .animate(controller: _controller)
            .slideY(
              begin: 0.3,
              end: 0,
              delay: 700.ms,
              duration: 600.ms,
              curve: Curves.easeOutQuad,
            )
            .fadeIn(delay: 700.ms, duration: 600.ms),
      ],
    );
  }

  Widget _buildPasswordForm() {
    return Column(
      key: const ValueKey('password_form'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Password field
        TextFormField(
          controller: _passwordController,
          obscureText: _isObscurePassword,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: Icon(
              Icons.lock_rounded,
              color: Theme.of(context).colorScheme.secondary,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _isObscurePassword
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                color: Theme.of(context).colorScheme.secondary.withOpacity(0.7),
              ),
              onPressed: () {
                setState(() {
                  _isObscurePassword = !_isObscurePassword;
                });
              },
            ),
            filled: true,
            fillColor:
                Theme.of(context).colorScheme.secondary.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.secondary,
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
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.8),
            ),
          ),
          validator: _validatePassword,
        ),

        const SizedBox(height: 16),

        // Confirm Password field
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _isObscureConfirmPassword,
          decoration: InputDecoration(
            labelText: 'Confirm Password',
            prefixIcon: Icon(
              Icons.lock_rounded,
              color: Theme.of(context).colorScheme.secondary,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _isObscureConfirmPassword
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                color: Theme.of(context).colorScheme.secondary.withOpacity(0.7),
              ),
              onPressed: () {
                setState(() {
                  _isObscureConfirmPassword = !_isObscureConfirmPassword;
                });
              },
            ),
            filled: true,
            fillColor:
                Theme.of(context).colorScheme.secondary.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.secondary,
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
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.8),
            ),
          ),
          validator: _validateConfirmPassword,
        ),

        const SizedBox(height: 16),

        // Password hint
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: Theme.of(context).colorScheme.secondary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Password must be at least 6 characters long',
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .secondary
                        .withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Action buttons
        Row(
          children: [
            Expanded(
              flex: 1,
              child: SizedBox(
                height: 55,
                child: OutlinedButton(
                  onPressed: _previousStep,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'BACK',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _signup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    foregroundColor: Theme.of(context).colorScheme.onSecondary,
                    shadowColor: Theme.of(context)
                        .colorScheme
                        .secondary
                        .withOpacity(0.4),
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
                            color: Theme.of(context).colorScheme.onSecondary,
                          ),
                        )
                      : const Text(
                          'SIGN UP',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
