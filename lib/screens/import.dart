import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:music_app/audio/audio_tile.dart' as at;
import 'package:music_app/core/custom_app_bar.dart' as cab;
import 'package:music_app/utils/conversion.dart' as conv;
import 'package:music_app/main.dart' show activeNotificationEntry;

class ImportPage extends StatefulWidget {
  const ImportPage({super.key, this.showSavedMessage = true});

  final bool showSavedMessage;
  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  final List<File> _importedFiles = [];

  List<String> get _allowedExtensions {
    if (Platform.isIOS) {
      return ['wav', 'mp3', 'flac', 'm4a', 'aac', 'opus'];
    }
    if (Platform.isAndroid) {
      return ['wav', 'mp3', 'flac'];
    }
    return ['wav', 'mp3', 'flac'];
  }

  Widget _buildSupportedFilesText() {
    final extensionSpans = <InlineSpan>[];
    for (var i = 0; i < _allowedExtensions.length; i++) {
      extensionSpans.add(
        TextSpan(
          text: '.${_allowedExtensions[i]}',
          style: TextStyle(color: Colors.grey[500], fontFamily: 'monospace'),
        ),
      );
      if (i < _allowedExtensions.length - 1) {
        extensionSpans.add(const TextSpan(text: ', '));
      }
    }

    return Text.rich(
      TextSpan(
        style: const TextStyle(color: Colors.grey, fontSize: 12),
        children: [
          const TextSpan(text: 'Supported files: '),
          ...extensionSpans,
        ],
      ),
    );
  }

  Future<void> _pickAndImportAudio() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
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
              border: Border.all(color: Colors.grey[700]!, width: ringWidth),
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
        if (_importedFiles.isNotEmpty && widget.showSavedMessage) {
          final bottomPadding = MediaQuery.of(context).padding.bottom;
          final overlayState = Navigator.of(context).overlay!;
          late OverlayEntry entry;
          entry = OverlayEntry(
            builder: (_) => Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(height: 2, color: conv.infernoColormap(0.7)),
                    Container(
                      width: double.infinity,
                      color: const Color.fromARGB(255, 18, 18, 18),
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPadding),
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
            ),
          );
          overlayState.insert(entry);
          activeNotificationEntry = entry;
          Future.delayed(const Duration(seconds: 6), () {
            if (activeNotificationEntry == entry) {
              entry.remove();
              activeNotificationEntry = null;
            }
          });
        }
        Navigator.of(context).pop(result);
      },
      child: Scaffold(
        appBar: const cab.CustomAppBar(title: 'Import Audio'),
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
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Import audio files',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              _buildSupportedFilesText(),
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
                      separatorBuilder: (context, index) => const Divider(
                        color: Color.fromARGB(255, 80, 80, 80),
                      ),
                      itemBuilder: (context, index) {
                        final file = _importedFiles[index];
                        return SizedBox(
                          height: 60,
                          child: at.AudioTile(
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
                          _buildSupportedFilesText(),
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
                    separatorBuilder: (context, index) => const Divider(
                      color: Color.fromARGB(255, 80, 80, 80),
                    ),
                    itemBuilder: (context, index) {
                      final file = _importedFiles[index];
                      return SizedBox(
                        height: 60,
                        child: at.AudioTile(
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
