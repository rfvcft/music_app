import 'dart:io';

import 'package:flutter/material.dart';
import 'package:music_app/screens/audio.dart';
import 'package:music_app/screens/import.dart';
import 'package:music_app/utils/custom_app_bar.dart' as cab;
import 'package:music_app/utils/constants.dart' as cnst;
import 'package:path_provider/path_provider.dart';
import 'package:music_app/main.dart' show activeNotificationEntry;
import 'package:music_app/audio/audio_tile.dart' as at;
import 'package:music_app/utils/conversion.dart' as conv;


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
    activeNotificationEntry?.remove();
    activeNotificationEntry = null;
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

  Widget _actionButton(BuildContext context, IconData icon, Color iconColor, String tooltip, VoidCallback onPressed) {
    const double size = 56;
    return Tooltip(
      message: tooltip,
      child: SizedBox(
      width: size,
      height: size,
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.grey[700]!,
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
          borderRadius: BorderRadius.circular(16),
        ),
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 18, 18, 18),
            side: BorderSide(color: conv.infernoColormap(0.7), width: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: EdgeInsets.zero,
          ),
          onPressed: onPressed,
          child: Icon(icon, color: iconColor, size: 24),
        ),
      ),
    ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const cab.CustomAppBar(title: 'Archive'),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _actionButton(context, Icons.mic, cnst.recordIconColor, 'Record audio',
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AudioPage(showSavedMessage: false)))
                  .then((_) => _loadAudioFiles())),
          const SizedBox(width: 16),
          _actionButton(context, Icons.file_upload, cnst.importIconColor, 'Import audio',
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ImportPage(showSavedMessage: false)))
                  .then((_) => _loadAudioFiles())),
        ],
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
                  child: at.AudioTile(
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
              separatorBuilder: (context, index) => const Divider(
                color: Color.fromARGB(255, 80, 80, 80),
              ),
              itemCount: _audioFiles.length,
            ),
    );
  }
}
