import 'package:flutter/material.dart';

import 'package:music_app/ffi/audio_processing_ffi.dart';

import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';



const List<String> audioNames = [
  'c_major_scale',
  'cant_help_falling_in_love',
  'dont_stop_believing',
  'heathens',
  'hey_jude',
  'nur_ein_wort',
  'on_the_nature_of_daylight',
  'rolling_in_the_deep',
];


class BackendPage extends StatefulWidget {
  const BackendPage({Key? key}) : super(key: key);

  @override
  State<BackendPage> createState() => _BackendPageState();
}

class _BackendPageState extends State<BackendPage> {
  final Map<String, String> _analysisSummaries = {};
  final Map<String, List<List<double>>> _chromagrams = {};
  bool _loading = false;

  /// Workaround for using assets with native code/FFI.
  /// Copies the asset from the Flutter bundle to a temporary file,
  /// so it can be accessed by native libraries expecting a file path.
  Future<String> _copyAssetToTemp(String assetName) async {
    final byteData = await rootBundle.load('assets/analyzed_examples/input/$assetName.m4a');
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$assetName.m4a');
    await file.writeAsBytes(byteData.buffer.asUint8List());
    return file.path;
  }

  /// Loads the asset, analyzes it using AudioProcessingFfi, and updates the UI with results.
  /// Handles errors and manages loading state.
  Future<void> _analyze(String assetName) async {
    setState(() => _loading = true);
    try {
      final filePath = await _copyAssetToTemp(assetName);
      // Use AudioProcessingFfi to load and analyze audio
      final audioProcessor = AudioProcessingFfi();
      final result = audioProcessor.loadAndAnalyze(filePath);
      final key = result['key'] ?? '';
      final duration = result['duration']?.toStringAsFixed(2) ?? '';
      final chromagram = result['chromagram'] as List<List<double>>?;
      String chromaShape = '';
      if (chromagram != null) {
        chromaShape = '${chromagram.length} x '
            '${chromagram.isNotEmpty ? chromagram[0].length : 0}';
      }
      setState(() {
        _analysisSummaries[assetName] =
            'Key: $key\nDuration: $duration s\nChromagram: $chromaShape';
        if (chromagram != null) {
          _chromagrams[assetName] = chromagram;
        }
      });
    } catch (e) {
      setState(() {
        _analysisSummaries[assetName] = 'Error: $e';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  void _pushChromagramPage(BuildContext context, String assetName) {
    final chromagram = _chromagrams[assetName];
    if (chromagram == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChromagramPage(
          assetName: assetName,
          chromagram: chromagram,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analyze m4a')),
      body: ListView(
        children: [
          for (final name in audioNames)
            ListTile(
              title: Text(name),
        subtitle: _analysisSummaries.containsKey(name)
          ? Text(_analysisSummaries[name] ?? '')
          : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 28,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                        minimumSize: const Size(0, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: _loading ? null : () => _analyze(name),
                      child: const Text('Analyze', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 28,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                        minimumSize: const Size(0, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: _chromagrams.containsKey(name)
                          ? () => _pushChromagramPage(context, name)
                          : null,
                      child: const Text('Show Chromagram', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}


class ChromagramPage extends StatelessWidget {
  final String assetName;
  final List<List<double>> chromagram;

  const ChromagramPage({required this.assetName, required this.chromagram, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // chromagram: List<List<double>> where outer list is bins (12), inner is frames
    final int numBins = chromagram.length;
    final int numFrames = chromagram.isNotEmpty ? chromagram[0].length : 0;

    // Transpose chromagram for display: frames as rows, bins as columns
    List<List<double>> transposed = List.generate(
      numFrames,
      (frame) => List.generate(numBins, (bin) => chromagram[bin][frame]),
    );

    const double cellWidth = 28;
    const double cellHeight = 22;
    const double fontSize = 10;

    return Scaffold(
      appBar: AppBar(title: Text('Chromagram: $assetName')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: bin labels
          Row(
            children: [
              SizedBox(
                width: cellWidth,
                child: Text('Fr', style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize)),
              ),
              for (int bin = numBins - 1; bin >= 0; bin--)
                Container(
                  width: cellWidth,
                  alignment: Alignment.center,
                  child: Text('B$bin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize)),
                ),
            ],
          ),
          const Divider(height: 1),
          // Matrix: each row is a frame, each column is a bin
          Expanded(
            child: ListView.builder(
              reverse: true, // so frame 0 is at the bottom
              itemCount: numFrames,
              itemBuilder: (context, frame) {
                return Row(
                  children: [
                    Container(
                      width: cellWidth,
                      height: cellHeight,
                      alignment: Alignment.center,
                      child: Text('F$frame', style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize)),
                    ),
                    for (int bin = numBins - 1; bin >= 0; bin--)
                      Container(
                        width: cellWidth,
                        height: cellHeight,
                        alignment: Alignment.center,
                        child: Container(
                          color: transposed[frame][bin] != 0.0 ? Colors.yellow.withOpacity(0.5) : Colors.transparent,
                          child: Text(
                            transposed[frame][bin].toStringAsFixed(2),
                            style: TextStyle(
                              fontSize: fontSize,
                              color: transposed[frame][bin] != 0.0 ? Colors.red : Colors.grey,
                              fontWeight: transposed[frame][bin] != 0.0 ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

