import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:quizify/providers/auth_provider.dart' as quizify_auth;
// import 'package:quizify/providers/theme_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _checkingOnboarding = true;
   @override
    void initState() {
      super.initState();
      _checkOnboardingStatus();
    }

    Future<void> _checkOnboardingStatus() async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;


      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final hasSeenOnboarding = userDoc.data()?['has_seen_onboarding'] ?? false;

      if (!hasSeenOnboarding) {
        context.go('/app/creator/onboarding');
      }
      else {
        setState(() {
          _checkingOnboarding = false;
        });
      }
    }

  @override
  Widget build(BuildContext context) {

    if (_checkingOnboarding) {
      // prevent flashing home screen
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final authProvider = Provider.of<quizify_auth.AuthProvider>(context);
    // final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text('Home'),
        // actions: [
        //   IconButton(
        //     onPressed: () {
        //       themeProvider.toggleTheme();
        //     },
        //     icon: Icon(
        //       themeProvider.isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
        //       color: Theme.of(context).colorScheme.inverseSurface,
        //     ),
        //   ),
        // ],
      ),
      body: Center(
        
        child: Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                      onPressed: () async {
                        await authProvider.logout();
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
                        'Logout',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
