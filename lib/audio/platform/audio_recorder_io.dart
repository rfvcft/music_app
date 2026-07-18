// ignore_for_file: avoid_print

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

mixin AudioRecorderMixin {
  Future<void> recordFile(AudioRecorder recorder, RecordConfig config) async {
    final path = await _getPath(encoder: config.encoder);

    await recorder.start(config, path: path);
  }

  Future<void> recordStream(AudioRecorder recorder, RecordConfig config) async {
    final path = await _getPath(encoder: config.encoder);

    final file = File(path);

    final stream = await recorder.startStream(config);

    stream.listen(
      (data) {
        file.writeAsBytesSync(data, mode: FileMode.append);
      },
      onDone: () {
        print('End of stream. File written to $path.');
      },
    );
  }

  void downloadWebData(String path) {}

  Future<String> _getPath({required AudioEncoder encoder}) async {
    final dir = await getApplicationDocumentsDirectory();
    final extension = _fileExtensionForEncoder(encoder);
    return p.join(
      dir.path,
      'audio_${DateTime.now().millisecondsSinceEpoch}.$extension',
    );
  }

  String _fileExtensionForEncoder(AudioEncoder encoder) {
    switch (encoder) {
      case AudioEncoder.wav:
        return 'wav';
      case AudioEncoder.aacLc:
      case AudioEncoder.aacEld:
      case AudioEncoder.aacHe:
        return 'm4a';
      case AudioEncoder.opus:
        return 'opus';
      case AudioEncoder.amrNb:
      case AudioEncoder.amrWb:
        return 'amr';
      case AudioEncoder.flac:
        return 'flac';
      case AudioEncoder.pcm16bits:
        return 'pcm';
    }
  }
}
