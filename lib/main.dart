import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quizify/firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'router.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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

          return MaterialApp.router(
            title: 'Quizify',
            routerConfig: router,
            debugShowCheckedModeBanner: false,
            theme: context.watch<ThemeProvider>().lightTheme,
            darkTheme: context.watch<ThemeProvider>().darkTheme,
            themeMode: context.watch<ThemeProvider>().themeMode,
            builder: auth.isLoading
                ? (ctx, child) => Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    )
                : null,
          );
        },
      ),
    );
  }
}