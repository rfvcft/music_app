import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:music_app/audio/audio_player.dart';
import 'package:music_app/audio/audio_recorder.dart';

import 'dart:io';

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

  Future<void> _promptForNameAndShowPlayer(String path) async {
    String? audioName = await showDialog<String>(
      context: context,
      builder: (context) {
        final TextEditingController controller = TextEditingController();
        return AlertDialog(
          title: const Text('Name your recording'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Enter audio name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
    if (audioName != null && audioName.isNotEmpty) {
      // Rename the file to the user-chosen name in the same directory
      try {
        final oldFile = File(path);
        final dir = oldFile.parent;
        final newPath = dir.path + '/$audioName.m4a';
        final newFile = await oldFile.rename(newPath);
        setState(() {
          audioPath = newFile.path;
          showPlayer = true;
        });
        if (kDebugMode) print('Audio renamed to: $newPath');
      } catch (e) {
        if (kDebugMode) print('Rename failed: $e');
        // Fallback: show original file
        setState(() {
          audioPath = path;
          showPlayer = true;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
                  _promptForNameAndShowPlayer(path);
                },
              ),
      ),
    );
  }
}
