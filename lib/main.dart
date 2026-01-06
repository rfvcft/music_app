import 'package:flutter/material.dart';

import 'package:music_app/screens/home.dart';

void main() {
  runApp(const MusicApp());
}

class MusicApp extends StatelessWidget {
  const MusicApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dodeca',
      theme: ThemeData(
        colorScheme: ColorScheme(
          brightness: Brightness.dark, // Overall theme brightness. Not important if individual colors are set.
          primary: Colors.green, // Used for floating action buttons, switches (on state), etc.
          onPrimary: Colors.white,
          secondary: Colors.pink, // Used in audio player visual
          onSecondary: Colors.purple, 
          surface: Colors.grey[850]!, // Used in switches (off state), etc.
          onSurface: Colors.white, // Text, icon button, etc. 
          error: Color(0xFFCF4446), // Error messages
          onError: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.black, // Background color for scaffolds (used in home, visualize, etc.)
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[900], // AppBar background color
          foregroundColor: Colors.white, // AppBar text color
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: WidgetStatePropertyAll<Color>(Colors.grey[800]!), // Button background color
            foregroundColor: WidgetStatePropertyAll<Color>(Colors.white),
            // Remove custom shape to use the default Material button shape
            elevation: WidgetStatePropertyAll<double>(12), // Higher elevation for 3D effect
            shadowColor: WidgetStatePropertyAll<Color>(Colors.grey[600]!), // Optional: shadow color
          ),
        ),
      ),
      home: const HomePage(title: 'DODECA'),
    );
  }
}
