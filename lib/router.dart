import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:quizify/providers/auth_provider.dart';
import 'package:quizify/screens/signup_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

final GoRouter router = GoRouter(
  initialLocation: '/app/home',
  refreshListenable: AuthProvider(),  // Singleton authProvider
  redirect: (context, state) {

    final isLoggedIn = context.read<AuthProvider>().isLoggedIn;
    final goingTo = state.matchedLocation;

    if(goingTo == '/') {
      return null;  // No redirect needed for splash screen
    }

    // If not logged in and trying to access protected routes, redirect to login
    if (!isLoggedIn && !goingTo.startsWith('/auth')) {
      return '/auth/login';
    }

    // If logged in and trying to go to login/signup, redirect to home
    if (isLoggedIn && goingTo.startsWith('/auth')) {
      return '/app/home';
    }

    return null;  // No redirect
  },
  routes: [
    // PUBLIC ROUTES (No auth required)
    GoRoute(
      path: '/auth',
      redirect: (BuildContext context, GoRouterState state) {
        final isLoggedIn = context.read<AuthProvider>().isLoggedIn;
        if(isLoggedIn) return '/app/home';  // Redirect to home if logged in
        
        // Redirect /auth to /auth/login
        if (state.fullPath == '/auth') {
          return '/auth/login';
        }

        return null;  // No redirect needed
      },
      routes: [
        GoRoute(
          path: 'login',
          builder: (BuildContext context, GoRouterState state) => LoginScreen(),
        ),
        GoRoute(
          path: 'signup',
          builder: (BuildContext context, GoRouterState state) => SignUpScreen(),
        ),
      ],
    ),
    
    // PROTECTED ROUTES (Login required)
    GoRoute(
      path: '/app',
      redirect: (BuildContext context, GoRouterState state) {
        final isLoggedIn = context.read<AuthProvider>().isLoggedIn;
        if(!isLoggedIn) return '/auth/login';  // Redirect to login if not logged in
        
        // Redirect /app to /app/home
        if (state.fullPath == '/app') {
          return '/app/home';
        }

        return null;  // No redirect needed
      },
      
      routes: [
        GoRoute(
          path: 'home',
          builder: (BuildContext context, GoRouterState state) => HomeScreen(),
        ),
        // GoRoute(
        //   path: 'profile',
        //   builder: (BuildContext context, GoRouterState state) => ProfileScreen(),
        // ),
        // More protected routes go here...
      ],
    ),
    
    // SplashScreen, it could also be part of the public routes, so it's fine as it is
    GoRoute(
      path: '/',
      // builder: (BuildContext context, GoRouterState state) => SplashScreen(),
      redirect: (context, state) => '/app/home',
    ),
  ],
);
