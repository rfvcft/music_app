import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../screens/analyze.dart';


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

  @override
  Widget build(BuildContext context) {
    final name = p.basename(widget.file.path);
    final audioUrl = widget.file.path;
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final dateStr = _modified == null
        ? ''
        : '${_modified!.day} ${months[_modified!.month - 1]} ${_modified!.year}';
    return ListTile(
      title: Text(name),
      subtitle: Text(dateStr),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AnalyzePage(
              audioUrl: audioUrl,
            ),
          ),
        );
      },
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
        if (result == 'rename') {
          final oldBase = p.basenameWithoutExtension(audioUrl);
          final ext = p.extension(audioUrl);
          String tempName = oldBase;
          final newBase = await showDialog<String>(
            context: context,
            builder: (context) {
              final controller = TextEditingController(text: tempName);
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
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, controller.text),
                    child: Text('Rename'),
                  ),
                ],
              );
            },
          );
          if (newBase != null && newBase.isNotEmpty && newBase != oldBase) {
            final file = File(audioUrl);
            final newPath = p.join(file.parent.path, newBase + ext);
            final renamed = await file.rename(newPath);
            await widget.onRename(renamed);
            await _fetchModifiedForFile(renamed);
          } else {
            await widget.onRename(null);
          }
        } else if (result == 'delete') {
          final fileName = p.basename(audioUrl);
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Delete File'),
              content: Text('Are you sure you want to delete "$fileName"?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('Delete'),
                ),
              ],
            ),
          );
          if (confirm == true) {
            final file = File(audioUrl);
            await file.delete();
            await widget.onDelete();
          }
        }
      },
    );
  }
}