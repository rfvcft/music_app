import 'dart:io';

import 'package:flutter/material.dart';
import 'package:music_app/screens/analyze.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:music_app/audio/audio_tile.dart';


/// ArchivePage displays a list of all audio files stored in the app's documents directory.
///
/// It shows the files in reverse chronological order (most recently modified first) and allows users
/// to rename or delete files using the AudioTile widget. The list updates automatically after any change.
class ArchivePage extends StatefulWidget {
  const ArchivePage({super.key});

  @override
  State<ArchivePage> createState() => _ArchivePageState();
}


class _ArchivePageState extends State<ArchivePage> {
  List<File> _audioFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAudioFiles();
  }

  Future<void> _loadAudioFiles() async {
    Directory dir = await getApplicationDocumentsDirectory();
    final files = dir.listSync().whereType<File>().toList();
    files.sort((a, b) {
      final aMod = a.statSync().modified;
      final bMod = b.statSync().modified;
      return bMod.compareTo(aMod);
    });
    setState(() {
      _audioFiles = files;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Archive"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _audioFiles.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32.0),
                    child: Text(
                      'No audio files yet.\nRecord or import audio to get started.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ),
                )
              : ListView.separated(
              itemBuilder: (context, index) {
                return Container(
                  height: 60,
                  child: AudioTile(
                    file: _audioFiles[index],
                    onRename: (renamedFile) async {
                      // Reload the file list after rename
                      await _loadAudioFiles();
                    },
                    onDelete: () async {
                      // Remove the file from the list immediately for Dismissible
                      setState(() {
                        _audioFiles.removeAt(index);
                      });
                      // Optionally reload from disk to ensure sync
                      await _loadAudioFiles();
                    },
                  ),
                );
              },
              separatorBuilder: (context, index) => const Divider(),
              itemCount: _audioFiles.length,
            ),
    );
  }
}
