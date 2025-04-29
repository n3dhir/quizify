import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quizify/firebase_options.dart';
import 'package:quizify/providers/theme_provider.dart';
import 'router.dart';
import 'providers/auth_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
// Load .env file before anything else
  await dotenv.load(fileName: ".env");
  // await dotenv.load();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  ); // Initialize Firebase

  final themeProvider = ThemeProvider();
  await themeProvider.init();

  runApp(MyApp(themeProvider: themeProvider));
}

class MyApp extends StatelessWidget {
  final ThemeProvider themeProvider;

  const MyApp({super.key, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
      ],
      child: Builder(
        builder: (context) {
          final auth = context.watch<AuthProvider>();
          final themeData = context.watch<ThemeProvider>().themeData;

          // Always use MaterialApp.router to maintain router state
          return MaterialApp.router(
            routerConfig: router,
            theme: themeData,
            debugShowCheckedModeBanner: false,
            // Show loading overlay if needed
            builder: auth.isLoading
                ? (context, child) => Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    )
                : null,
          );
        },
      ),
    );
  }
}
