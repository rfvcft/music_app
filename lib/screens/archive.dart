import 'dart:io';

import 'package:flutter/material.dart';
import 'package:music_app/screens/analyze.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:audioplayers/audioplayers.dart';

class ArchivePage extends StatefulWidget {
  const ArchivePage({super.key});

  @override
  State<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends State<ArchivePage> {
  late Future<List<File>> _audioFiles;
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlaying;
  bool _isPlaying = false;

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
    bool isThisPlaying = _currentlyPlaying == audioUrl && _isPlaying;
    return ListTile(
      title: Text(name),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AnalyzePage(
              audioName: name,
              audioUrl: audioUrl,
            ),
          ),
        );
      },
      trailing: IconButton(
        onPressed: () async {
          if (isThisPlaying) {
            await _audioPlayer.pause();
            setState(() {
              _isPlaying = false;
            });
          } else {
            await _audioPlayer.stop();
            await _audioPlayer.play(DeviceFileSource(audioUrl));
            setState(() {
              _currentlyPlaying = audioUrl;
              _isPlaying = true;
            });
          }
        },
        icon: Icon(isThisPlaying ? Icons.pause : Icons.play_arrow),
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
                        child: _audioTile(p.basename(files[index].path), files[index].path),
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
