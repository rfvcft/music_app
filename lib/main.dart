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
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const HomePage(title: 'Music App'),
    );
  }
}
