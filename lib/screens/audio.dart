import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:music_app/audio/audio_recorder.dart';
import 'package:music_app/audio/audio_tile.dart';
import 'dart:io';

class AudioPage extends StatefulWidget {
  const AudioPage({super.key});

  @override
  State<AudioPage> createState() => _AudioPageState();
}

class _AudioPageState extends State<AudioPage> {
  final List<File> _sessionFiles = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Record audio"),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.maxWidth;
          return Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Recorder(
                width: size,
                height: size,
                onStop: (path) {
                  if (kDebugMode) print('Recorded file path: $path');
                  setState(() {
                    _sessionFiles.insert(0, File(path)); // Newest first
                  });
                },
              ),
              const SizedBox(height: 24),
              if (_sessionFiles.isNotEmpty)
                Expanded(
                  child: ListView.separated(
                    itemCount: _sessionFiles.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final file = _sessionFiles[index];
                      return AudioTile(
                        file: file,
                        onRename: (renamedFile) async {
                          if (renamedFile != null) {
                            setState(() {
                              _sessionFiles[index] = renamedFile;
                            });
                          }
                        },
                        onDelete: () async {
                          setState(() {
                            _sessionFiles.removeAt(index);
                          });
                        },
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
