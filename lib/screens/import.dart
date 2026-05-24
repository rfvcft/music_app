import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:music_app/audio/audio_tile.dart';
import 'package:music_app/utils/conversion.dart' as conv;

class ImportPage extends StatefulWidget {
  const ImportPage({super.key});

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  final List<File> _importedFiles = [];

  Future<void> _pickAndImportAudio() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['wav', 'mp3', 'm4a'],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    final appDir = await getApplicationDocumentsDirectory();

    for (final pickedFile in result.files) {
      if (pickedFile.path == null) continue;
      final source = File(pickedFile.path!);
      final destPath = p.join(appDir.path, pickedFile.name);

      // Avoid overwriting existing files
      File dest = File(destPath);
      if (await dest.exists()) {
        final base = p.basenameWithoutExtension(pickedFile.name);
        final ext = p.extension(pickedFile.name);
        int counter = 1;
        do {
          dest = File(p.join(appDir.path, '$base ($counter)$ext'));
          counter++;
        } while (await dest.exists());
      }

      await source.copy(dest.path);
      setState(() {
        _importedFiles.insert(0, dest);
      });
    }
  }

  Widget _buildImportControl(double screenRadius) {
    const double iconSize = 36;
    final double diskRadius = screenRadius * 0.25;
    final double ringWidth = screenRadius * 0.025;

    return ClipOval(
      child: Material(
        color: Colors.black,
        child: InkWell(
          onTap: _pickAndImportAudio,
          child: Container(
            width: 2 * (diskRadius + ringWidth),
            height: 2 * (diskRadius + ringWidth),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey, width: ringWidth),
            ),
            child: const Center(
              child: Icon(Icons.file_upload, color: Colors.white, size: iconSize),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        if (_importedFiles.isNotEmpty) {
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
          title: Text("Import Audio"),
        ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isLandscape = constraints.maxWidth > constraints.maxHeight;
          final size = isLandscape ? constraints.maxHeight : constraints.maxWidth;
          final screenRadius = size / 2;

          if (isLandscape) {
            return Row(
              children: [
                SizedBox(
                  width: size,
                  height: size,
                  child: Stack(
                    children: [
                      Center(child: _buildImportControl(screenRadius)),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 60),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Import audio files',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Only .wav, .mp3 and .m4a files supported',
                                style: TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_importedFiles.isNotEmpty)
                  Expanded(
                    child: ListView.separated(
                      itemCount: _importedFiles.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final file = _importedFiles[index];
                        return SizedBox(
                          height: 60,
                          child: AudioTile(
                            file: file,
                            onRename: (renamedFile) async {
                              if (renamedFile != null) {
                                setState(() {
                                  _importedFiles[index] = renamedFile;
                                });
                              }
                            },
                            onDelete: () async {
                              setState(() {
                                _importedFiles.removeAt(index);
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

          return Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: Stack(
                  children: [
                    Center(child: _buildImportControl(screenRadius)),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Import audio files',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Only .wav, .mp3 and .m4a files supported',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          const SizedBox(height: 10),
                          const SizedBox(height: 60),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (_importedFiles.isNotEmpty)
                Expanded(
                  child: ListView.separated(
                    itemCount: _importedFiles.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final file = _importedFiles[index];
                      return SizedBox(
                        height: 60,
                        child: AudioTile(
                          file: file,
                          onRename: (renamedFile) async {
                            if (renamedFile != null) {
                              setState(() {
                                _importedFiles[index] = renamedFile;
                              });
                            }
                          },
                          onDelete: () async {
                            setState(() {
                              _importedFiles.removeAt(index);
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
