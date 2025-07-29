import 'package:flutter/material.dart';
import 'package:music_app/archive.dart';
import 'package:music_app/audio.dart';
import 'package:music_app/import.dart';
import 'package:music_app/settings.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Widget _pageButton(String title, Widget route) {
    return ElevatedButton(
      child: Text(
        title,
        style: TextStyle(fontSize: 24.0),
      ),
      onPressed: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => route));
      },
    );
  }

  Widget _iconButton(IconData iconData, Widget route) {
    return IconButton(
      icon: Icon(iconData),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => route),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [_iconButton(Icons.settings, SettingsPage())],
      ),
      body: Center(
        child: Column(
          spacing: 30,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _pageButton("Record audio", AudioPage()),
            _pageButton("Import audio", ImportPage()),
            _pageButton("Archive", ArchivePage()),
          ],
        ),
      ),
    );
  }
}
