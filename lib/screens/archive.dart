import 'dart:io';

import 'package:flutter/material.dart';
import 'package:music_app/screens/analyze.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ArchivePage extends StatefulWidget {
  const ArchivePage({super.key});

  @override
  State<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends State<ArchivePage> {
  late Future<List<File>> _audioFiles;

  @override
  void initState() {
    super.initState();
    _audioFiles = _getAudioFiles();
  }

  Future<List<File>> _getAudioFiles() async {
    Directory dir = await getApplicationDocumentsDirectory();
    return dir.listSync().whereType<File>().toList();
  }

  Widget _audioTile(String name, String audioUrl) {
    return ListTile(
      title: Text(name),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AnalyzePage(
              audioUrl: audioUrl,
            ),
          ),
        );
      },
      trailing: IconButton(
        onPressed: () {
          //TODO: add possibility to play the audio here as well?
          /* PLAY AUDIO */
        },
        icon: Icon(Icons.play_arrow),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text("Archive"),
      ),
      body: FutureBuilder(
        future: _audioFiles,
        builder: (context, asyncSnapshot) {
          if (!asyncSnapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(),
            );
          } else {
            List<File> files = asyncSnapshot.data!;
            return ListView.separated(
              itemBuilder: (context, index) {
                return Container(
                  height: 50,
                  color: Colors.blue,
                  child: _audioTile("Entry ${p.basename(files[index].path)}", files[index].path),
                );
              },
              separatorBuilder: (context, index) => const Divider(),
              itemCount: files.length,
            );
          }
        },
      ),
    );
  }
}
