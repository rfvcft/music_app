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
          seedColor: Color.fromARGB(255, 146, 5, 3),
          brightness: Brightness.dark,
          surface: Colors.grey,
        ),
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const HomePage(title: 'Music App'),
    );
  }
}
