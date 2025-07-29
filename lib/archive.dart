import 'package:flutter/material.dart';
import 'package:music_app/analyze.dart';

class ArchivePage extends StatefulWidget {
  const ArchivePage({super.key});

  @override
  State<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends State<ArchivePage> {
  final List<int> entries = List<int>.generate(50, (index) => index + 1);

  Widget _audioButton(String name, String audioUrl) {
    return TextButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AnalyzePage(
              audioUrl: audioUrl,
            ),
          ),
        );
      },
      child: Text(name),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text("Archive"),
      ),
      body: ListView.separated(
        itemBuilder: (context, index) {
          return Container(
            //TODO: add possibility to play the audio here as well?
            height: 50,
            color: Colors.cyanAccent,
            child: _audioButton("Entry ${entries[index]}", "/made/up/url/audio${index + 1}.wav"),
          );
        },
        separatorBuilder: (context, index) => const Divider(),
        itemCount: entries.length,
      ),
    );
  }
}
