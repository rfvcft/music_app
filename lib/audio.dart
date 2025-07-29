import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:music_app/audio_player.dart';
import 'package:music_app/audio_recorder.dart';

class AudioPage extends StatefulWidget {
  const AudioPage({super.key});

  @override
  State<AudioPage> createState() => _AudioPageState();
}

class _AudioPageState extends State<AudioPage> {
  bool showPlayer = false;
  String? audioPath;

  @override
  void initState() {
    showPlayer = false;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text("Audio Recorder"),
      ),
      body: Center(
        child: showPlayer
            ? AudioPlayer(
                source: audioPath!,
                onDelete: () {
                  setState(() => showPlayer = false);
                },
              )
            : Recorder(
                onStop: (path) {
                  if (kDebugMode) print('Recorded file path: $path');
                  setState(() {
                    audioPath = path;
                    showPlayer = true;
                  });
                },
              ),
      ),
    );
  }
}
