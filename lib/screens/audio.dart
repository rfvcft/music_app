import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:music_app/audio/audio_recorder.dart';
import 'package:music_app/audio/audio_tile.dart';
import 'package:music_app/utils/conversion.dart' as conv;
import 'dart:io';

class AudioPage extends StatefulWidget {
  const AudioPage({super.key});

  @override
  State<AudioPage> createState() => _AudioPageState();
}

class _AudioPageState extends State<AudioPage> {
  final List<File> _sessionFiles = [];
  final _recorderKey = GlobalKey(); // Preserves Recorder state across orientation changes

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        if (_sessionFiles.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 6),
              backgroundColor: Colors.transparent,
              elevation: 0,
              padding: EdgeInsets.zero,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(height: 2, color: conv.infernoColormap(0.7)),
                  Container(
                    width: double.infinity,
                    color: const Color.fromARGB(255, 18, 18, 18),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Files have been saved to  ',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 16,
                            fontWeight: FontWeight.w300,
                            letterSpacing: 1.5,
                          ),
                        ),
                        Icon(Icons.archive, color: Colors.grey[400], size: 20),
                        const SizedBox(width: 6),
                        Text(
                          'Archive',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 16,
                            fontWeight: FontWeight.w300,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        Navigator.of(context).pop(result);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text("Record Audio"),
        ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isLandscape = constraints.maxWidth > constraints.maxHeight;
          if (isLandscape) {
            final recorderSize = constraints.maxHeight;
            return Row(
              children: [
                Recorder(
                  key: _recorderKey,
                  width: recorderSize,
                  height: recorderSize,
                  onStop: (path) {
                    if (kDebugMode) print('Recorded file path: $path');
                    setState(() {
                      _sessionFiles.insert(0, File(path));
                    });
                  },
                ),
                if (_sessionFiles.isNotEmpty)
                  Expanded(
                    child: ListView.separated(
                      itemCount: _sessionFiles.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final file = _sessionFiles[index];
                        return SizedBox(
                          height: 60,
                          child: AudioTile(
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
                        ),
                        );
                      },
                    ),
                  ),
              ],
            );
          }
          final size = constraints.maxWidth;
          return Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Recorder(
                key: _recorderKey,
                width: size,
                height: size,
                onStop: (path) {
                  if (kDebugMode) print('Recorded file path: $path');
                  setState(() {
                    _sessionFiles.insert(0, File(path));
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
                      return SizedBox(
                        height: 60,
                        child: AudioTile(
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
                      ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
  }
}
