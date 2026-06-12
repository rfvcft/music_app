import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'package:music_app/utils/constants.dart' as cnst;
import 'package:music_app/screens/visualize.dart';
import 'package:music_app/ffi/audioanalysis_ffi.dart' as audioffi;



/// AudioTile displays an audio file entry in a list, showing its name and modification date.
///
/// Provides UI for renaming, and deleting the file. Tapping the tile opens the analysis page for the audio.
/// Long-pressing opens a bottom sheet with options to rename or delete the file. Rename and delete actions are handled
/// via callbacks to update the parent widget's state. The tile updates its display if the file is renamed.
typedef RenameCallback = Future<void> Function(File? newFile);
typedef DeleteCallback = Future<void> Function();

class AudioTile extends StatefulWidget {
  final File file;
  final RenameCallback onRename;
  final DeleteCallback onDelete;

  const AudioTile({
    super.key,
    required this.file,
    required this.onRename,
    required this.onDelete,
  });

  @override
  State<AudioTile> createState() => _AudioTileState();
}

class _AudioTileState extends State<AudioTile> {
  DateTime? _modified;

  @override
  void initState() {
    super.initState();
    _fetchModifiedForFile(widget.file);
  }

  Future<void> _fetchModifiedForFile(File file) async {
    final stat = await file.stat();
    setState(() {
      _modified = stat.modified;
    });
  }

  Future<void> _analyzeAndNavigate() async {
    final audioUrl = widget.file.path;
    final audioName = p.basename(widget.file.path);

    try {
      final result = audioffi.AudioProcessingFfi().loadAndAnalyze(audioUrl);
      if (result['key'] == null || result['duration'] == null || result['chromagram'] == null) {
        throw Exception('Analysis failed or incomplete.');
      }
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Visualizer(
            audioName: audioName,
            audioUrl: audioUrl,
            duration: result['duration'] as double,
            musicalKey: result['key'] as String,
            chromagram: result['chromagram'] as List<List<double>>,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Analysis failed: $e')),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    final name = p.basename(widget.file.path);
    final audioUrl = widget.file.path;
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final now = DateTime.now();
    final isToday = _modified != null &&
        _modified!.year == now.year &&
        _modified!.month == now.month &&
        _modified!.day == now.day;
    final dateStr = _modified == null
        ? ''
        : isToday
            ? '${_modified!.hour.toString().padLeft(2, '0')}:${_modified!.minute.toString().padLeft(2, '0')}'
            : '${_modified!.day} ${months[_modified!.month - 1]} ${_modified!.year}';
    return Dismissible(
      key: ValueKey(widget.file.path),
      direction: DismissDirection.endToStart,
      background: Row(
        children: [
          const Spacer(flex: 2),
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.red,
              alignment: Alignment.center,
              child: const Icon(Icons.delete, color: Colors.white),
            ),
          ),
        ],
      ),
      confirmDismiss: (direction) async {
        // Show confirmation dialog before deleting
        final fileName = p.basename(audioUrl);
        final dialogContext = context;
        final confirm = await showDialog<bool>(
          context: dialogContext,
          builder: (dialogContext) => AlertDialog(
            title: Text('Delete File'),
            content: Text('Are you sure you want to delete "$fileName"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text('Delete'),
              ),
            ],
          ),
        );
        return confirm == true;
      },
      onDismissed: (direction) async {
        final file = File(audioUrl);
        await file.delete();
        await widget.onDelete();
      },
      child: InkWell(
        onTap: _analyzeAndNavigate,
        onLongPress: () async {
          final result = await showModalBottomSheet<String>(
            context: context,
            builder: (context) {
              return SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: Icon(Icons.drive_file_rename_outline),
                      title: Text('Rename'),
                      onTap: () async {
                        Navigator.pop(context, 'rename');
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.delete),
                      title: Text('Delete'),
                      onTap: () {
                        Navigator.pop(context, 'delete');
                      },
                    ),
                  ],
                ),
              );
            },
          );
          if (!mounted) return;
          if (result == 'rename') {
            final oldBase = p.basenameWithoutExtension(audioUrl);
            final ext = p.extension(audioUrl);
            String tempName = oldBase;
            final dialogContext = context;
            final newBase = await showDialog<String>(
              context: dialogContext,
              builder: (dialogContext) {
                final controller = TextEditingController(text: tempName);
                // Select all text after the first frame
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length);
                });
                return AlertDialog(
                  title: Text('Rename File'),
                  content: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          autofocus: true,
                          decoration: InputDecoration(hintText: 'Enter new name'),
                          controller: controller,
                          onChanged: (value) => tempName = value,
                        ),
                      ),
                      Text(ext),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, controller.text),
                      child: Text('Rename'),
                    ),
                  ],
                );
              },
            );
            if (!mounted) return;
            if (newBase != null && newBase.isNotEmpty && newBase != oldBase) {
              final file = File(audioUrl);
              final newPath = p.join(file.parent.path, newBase + ext);
              final newFile = File(newPath);
              if (await newFile.exists()) {
                if (!mounted) return;
                // Show error dialog if file exists
                final errorDialogContext = context;
                await showDialog<void>(
                  context: errorDialogContext,
                  builder: (errorDialogContext) => AlertDialog(
                    title: Text('Rename Failed'),
                    content: Text('A file with that name already exists.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(errorDialogContext),
                        child: Text('OK'),
                      ),
                    ],
                  ),
                );
                if (!mounted) return;
                await widget.onRename(null);
              } else {
                final renamed = await file.rename(newPath);
                if (!mounted) return;
                await widget.onRename(renamed);
                await _fetchModifiedForFile(renamed);
              }
            } else {
              await widget.onRename(null);
            }
          } else if (result == 'delete') {
            final fileName = p.basename(audioUrl);
            final dialogContext = context;
            final confirm = await showDialog<bool>(
              context: dialogContext,
              builder: (dialogContext) => AlertDialog(
                title: Text('Delete File'),
                content: Text('Are you sure you want to delete "$fileName"?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: Text('Delete'),
                  ),
                ],
              ),
            );
            if (!mounted) return;
            if (confirm == true) {
              final file = File(audioUrl);
              await file.delete();
              await widget.onDelete();
            }
          }
        },
        child: SizedBox.expand(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: cnst.audioTileNameColor),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(dateStr, style: const TextStyle(color: cnst.audioTileDateColor)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}