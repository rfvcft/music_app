import 'dart:io';

import 'package:flutter/material.dart';
import 'package:music_app/screens/analyze.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../audio/audio_tile.dart';


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
    final files = dir.listSync().whereType<File>().toList();
    files.sort((a, b) {
      final aMod = a.statSync().modified;
      final bMod = b.statSync().modified;
      return bMod.compareTo(aMod);
    });
    return files;
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
                  height: 60,
                  child: AudioTile(
                    file: files[index],
                    onRename: () async {
                      setState(() {
                        _audioFiles = _getAudioFiles();
                      });
                    },
                    onDelete: () async {
                      setState(() {
                        _audioFiles = _getAudioFiles();
                      });
                    },
                  ),
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
