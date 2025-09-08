import 'package:flutter/material.dart';
import 'package:music_app/screens/archive.dart';
import 'package:music_app/screens/audio.dart';
import 'package:music_app/screens/import.dart';
import 'package:music_app/screens/load_assets.dart';
import 'package:music_app/screens/settings.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.title});

  final String title;

  Widget _pageButton(BuildContext context, title, Widget route) {
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

  Widget _iconButton(BuildContext context, IconData iconData, Widget route) {
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
        title: Text(title),
        actions: [_iconButton(context, Icons.settings, SettingsPage())],
      ),
      body: Center(
        child: Column(
          spacing: 30,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _pageButton(context, "Record audio", AudioPage()),
            _pageButton(context, "Import audio", ImportPage()),
            _pageButton(context, "Archive", ArchivePage()),
            _pageButton(context, "Frontend", LoadAssets()),
          ],
        ),
      ),
    );
  }
}
