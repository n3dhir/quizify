import 'package:flutter/material.dart';

ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.light(
    surface: Colors.white,
    primary: Colors.deepPurple.shade400,
    secondary: Colors.grey.shade100,
    tertiary: Colors.white,
    inversePrimary: Colors.grey.shade700,
    error: Colors.red.shade400, // Adding error color
    onPrimary: Colors.white, // Text color on primary elements
    onSecondary: Colors.black, // Text color on secondary elements
    onSurface: Colors.black, // Text color on surface elements
    onTertiary: Colors.black, // Text color on tertiary elements
    onError: Colors.white, // Text color on error elements
  ),
);
