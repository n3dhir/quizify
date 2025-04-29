import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quizify/providers/auth_provider.dart';
import 'package:quizify/providers/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: Icon(
              themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text('Dark Mode'),
            trailing: CupertinoSwitch(
              value: themeProvider.isDarkMode,
              onChanged: (value) {
                themeProvider.toggleTheme();
              },
              activeTrackColor: Theme.of(context).colorScheme.primary,
            ),
            onTap: () {
              themeProvider.toggleTheme();
            },
            splashColor: Colors.transparent,
            hoverColor: Colors.transparent,
          ),
          // const Divider(),
          // ListTile(
          //   leading: Icon(
          //     Icons.person,
          //     color: Theme.of(context).colorScheme.primary,
          //   ),
          // title: const Text('Account'),
          // subtitle: Text("sdgsdgsd" ?? 'Not logged in'),
          // ),
          const Divider(),
          ListTile(
            leading: Icon(
              Icons.logout,
              color: Theme.of(context).colorScheme.error,
            ),
            title: const Text('Logout'),
            onTap: () async {
              await authProvider.logout();
            },
          ),
        ],
      ),
    );
  }
}
