import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:quizify/providers/auth_provider.dart';
import 'package:quizify/screens/add_quiz_screen.dart';
import 'package:quizify/screens/join_quiz_screen.dart';
import 'package:quizify/screens/onboarding_screen.dart';
import 'package:quizify/screens/quiz_detail_screen.dart';
import 'package:quizify/screens/quiz_view_edit_screen.dart';
import 'package:quizify/screens/settings_screen.dart';
import 'package:quizify/screens/signup_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

final GoRouter router = GoRouter(
  initialLocation: '/',
  refreshListenable: AuthProvider(), // Singleton authProvider
  redirect: (context, state) {
    final isLoggedIn = context.read<AuthProvider>().isLoggedIn;
    final goingTo = state.matchedLocation;

    if (goingTo == '/') {
      return null; // No redirect needed for splash screen
    }

    // If not logged in and trying to access protected routes, redirect to login
    if (!isLoggedIn &&
        (!goingTo.startsWith('/auth') && !goingTo.startsWith('/quiz'))) {
      return '/auth/login';
    }

    // If logged in and trying to go to login/signup, redirect to home
    if (isLoggedIn &&
        (goingTo.startsWith('/auth') || goingTo.startsWith('/quiz'))) {
      return '/app/creator/home';
    }

    return null; // No redirect
  },
  routes: [
    // PUBLIC ROUTES (No auth required)
    GoRoute(
      path: '/auth',
      redirect: (BuildContext context, GoRouterState state) {
        final isLoggedIn = context.read<AuthProvider>().isLoggedIn;
        if (isLoggedIn)
          return '/app/creator/home'; // Redirect to home if logged in

        // Redirect /auth to /auth/login
        if (state.fullPath == '/auth') {
          return '/auth/login';
        }

        return null; // No redirect needed
      },
      routes: [
        GoRoute(
          path: 'login',
          builder: (BuildContext context, GoRouterState state) => LoginScreen(),
        ),
        GoRoute(
          path: 'signup',
          builder:
              (BuildContext context, GoRouterState state) => SignUpScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/quiz',
      redirect: (BuildContext context, GoRouterState state) {
        final isLoggedIn = context.read<AuthProvider>().isLoggedIn;
        if (isLoggedIn)
          return '/app/creator/home'; // Redirect to home if logged in

        // Redirect /auth to /auth/login
        if (state.fullPath == '/quiz') {
          return '/quiz/join';
        }

        return null; // No redirect needed
      },
      routes: [
        GoRoute(
          path: '/join',
          builder:
              (BuildContext context, GoRouterState state) => JoinQuizScreen(),
        ),
        // GoRoute(
        //   path: '/play',
        //   builder:
        //       (BuildContext context, GoRouterState state) => PlayQuizScreen(quizCode:),
        // ),
      ],
    ),

    // PROTECTED ROUTES (Login required)
    GoRoute(
      path: '/app',
      redirect: (BuildContext context, GoRouterState state) {
        final isLoggedIn = context.read<AuthProvider>().isLoggedIn;
        if (!isLoggedIn)
          return '/auth/login'; // Redirect to login if not logged in

        // Redirect /app to /app/creator/home
        if (state.fullPath == '/app') {
          return '/app/creator/home';
        }

        return null; // No redirect needed
      },
      routes: [
        GoRoute(
          path: 'creator',
          builder:
              (context, state) => Scaffold(
                appBar: AppBar(title: const Text('Creator')),
                body: Center(child: Text('Creator Home')),
              ),
          routes: [
            ShellRoute(
              builder: (context, state, child) {
                return Scaffold(
                  body: child,
                  bottomNavigationBar: BottomNavigationBar(
                    currentIndex:
                        state.uri.toString().contains('/creator/settings')
                            ? 1
                            : 0,
                    selectedItemColor: Theme.of(context).colorScheme.primary,
                    onTap: (index) {
                      if (index == 0) {
                        context.go('/app/creator/home');
                      } else {
                        context.go('/app/creator/settings');
                      }
                    },
                    items: const [
                      BottomNavigationBarItem(
                        icon: Icon(Icons.home),
                        label: 'Home',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.settings),
                        label: 'Settings',
                      ),
                    ],
                  ),
                );
              },
              routes: [
                GoRoute(
                  path: 'home', // ✅ Removed leading slash
                  name: 'creator_home',
                  builder: (context, state) => HomeScreen(),
                ),
                GoRoute(
                  path: 'settings', // ✅ Removed leading slash
                  name: 'creator_settings',
                  builder: (context, state) => SettingsScreen(),
                ),
              ],
            ),
            GoRoute(
              path: 'onboarding', // ✅ Removed leading slash
              name: 'creator_onboarding',
              builder: (context, state) => OnboardingScreen(),
            ),
            // This one stays outside the ShellRoute
            GoRoute(
              path: 'add', // ✅ Relative to /creator, becomes /app/creator/add
              name: 'creator_add',
              builder: (context, state) => AddQuizScreen(),
            ),
            GoRoute(
              path:
                  'details/:quiz_id', // ✅ Relative to /creator, becomes /app/creator/add
              name: 'quiz_details',
              builder: (context, state) {
                final quizId = state.pathParameters['quiz_id']!;
                return QuizDetailScreen(quiz_id: quizId);
              },
            ),
            GoRoute(
              path: 'view/:quiz_id',
              name: 'quiz_view',
              builder:
                  (context, state) => QuizViewEditScreen(
                    quizId: state.pathParameters['quiz_id']!,
                  ),
            ),
          ],
        ),
      ],
    ),

    // SplashScreen, it could also be part of the public routes, so it's fine as it is
    GoRoute(
      path: '/',
      // builder: (BuildContext context, GoRouterState state) => SplashScreen(),
      redirect: (context, state) => '/app/creator/home',
    ),
  ],
);
