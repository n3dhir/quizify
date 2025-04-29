import 'package:flutter/material.dart';

ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.dark(
      surface: Colors.grey.shade900,
      primary: Colors.deepPurple.shade400,
      secondary: Color.fromARGB(255, 30, 30, 30),
      tertiary: Color.fromARGB(255, 47, 47, 47),
      inversePrimary: Colors.grey.shade300,
      error: Colors.red.shade400, // Adding error color
      onPrimary: Colors.white, // Text color on primary elements
      onSecondary: Colors.white, // Text color on secondary elements
      onSurface: Colors.white, // Text color on surface elements
      onTertiary: Colors.white, // Text color on tertiary elements
      onError: Colors.white, // Text color on error elements
    ));
