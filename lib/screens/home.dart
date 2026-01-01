import 'package:flutter/material.dart';
import 'package:music_app/screens/archive.dart';
import 'package:music_app/screens/audio.dart';
import 'package:music_app/screens/import.dart';
import 'package:music_app/screens/load_assets.dart';
import 'package:music_app/screens/settings.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _switchValue = false;

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
        title: Text(widget.title),
        actions: [_iconButton(context, Icons.settings, SettingsPage())],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 12,
          children: <Widget>[
            _pageButton(context, "Record audio", AudioPage()),
            _pageButton(context, "Import audio", ImportPage()),
            _pageButton(context, "Archive", ArchivePage()),
            _pageButton(context, "Frontend", LoadAssets()),
            const SizedBox(height: 32),
            // Switch uses secondary color implicitly in dark mode
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Switch'),
                Switch(
                  value: _switchValue,
                  onChanged: (val) => setState(() => _switchValue = val),
                ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        tooltip: 'Primary Color Example',
        child: const Icon(Icons.star),
      ),
    );
  }
}
