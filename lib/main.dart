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
      title: 'Music App',
      theme: ThemeData(
        colorScheme: const ColorScheme(
          brightness: Brightness.dark, // Overall theme brightness. Not important if individual colors are set.
          primary: Colors.yellow, // Used for floating action buttons, switches (on state), etc.
          onPrimary: Colors.orange,
          secondary: Colors.green, // Used in audio player visual
          onSecondary: Colors.purple, 
          surface: Colors.pink, // Used in switches (off state), etc.
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
            backgroundColor: WidgetStatePropertyAll<Color>(Colors.grey),
            foregroundColor: WidgetStatePropertyAll<Color>(Colors.white),
            // Remove custom shape to use the default Material button shape
            elevation: WidgetStatePropertyAll<double>(12), // Higher elevation for 3D effect
            shadowColor: WidgetStatePropertyAll<Color>(Colors.white), // Optional: shadow color
          ),
        ),

      ),
      home: const HomePage(title: 'Music App'),
    );
  }
}
