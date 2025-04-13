import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quizify/providers/auth_provider.dart';
import 'package:quizify/providers/theme_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text('Home'),
        actions: [
          IconButton(
            onPressed: () {
              themeProvider.toggleTheme();
            },
            icon: Icon(
              themeProvider.isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: Theme.of(context).colorScheme.inverseSurface,
            ),
          ),
        ],
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
