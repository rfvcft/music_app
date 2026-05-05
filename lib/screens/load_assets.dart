import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle; // for access to assets

import 'package:music_app/screens/visualize.dart';

// Available options for backend simulator:
const List<String> audioNames = [
  'c_major_scale.m4a',
  'cant_help_falling_in_love.m4a',
  'dont_stop_believing.m4a',
  'heathens.m4a',
  'hey_jude.m4a',
  'nur_ein_wort.m4a',
  'on_the_nature_of_daylight.m4a',
  'rolling_in_the_deep.m4a',
  'every_note_piano.mp3',
  'g_major_scale_cello.wav',
];

class LoadAssets extends StatefulWidget {
  const LoadAssets({super.key});

  @override
  State<LoadAssets> createState() => _LoadAssetsState();
}

class _LoadAssetsState extends State<LoadAssets> {
  bool _isProcessing = false;

  Future<void> _loadAssetAndGoToVisualizer(String audioName) async {
    setState(() {
      _isProcessing = true;
    });

    // ================ SIMULATING ESSENTIA =====================
    // Path to audio
    String assetPath = 'assets/analyzed_examples/input/$audioName';
    print(assetPath);

    // Strip extension for output folder name
    final baseName = audioName.contains('.') ? audioName.substring(0, audioName.lastIndexOf('.')) : audioName;

    // Get key and duration of audio
    String meta = await rootBundle.loadString('assets/analyzed_examples/output/$baseName/meta.csv');
    String musicalKey = '';
    double duration = 0.0;

    final lines = meta.split('\n');
    for (final line in lines) {
      if (line.trim().isEmpty) continue;

      final parts = line.split(',');
      if (parts.length != 2) continue;

      final field = parts[0].trim();
      final value = parts[1].trim();

      if (field == 'key') {
        musicalKey = value;
      } else if (field == 'duration') {
        duration = double.tryParse(value) ?? 0.0;
      }
    }

    // Load chromagram
    String chromagramStr = await rootBundle.loadString('assets/analyzed_examples/output/$baseName/chromagram.csv');
    final List<List<double>> chromagram = [];

    final rows = chromagramStr.split('\n');
    for (final line in rows) {
      if (line.trim().isEmpty) continue;

      final row = line.split(',').map((s) => double.parse(s.trim())).toList();
      chromagram.add(row);
    }

    // Simulate processing
    await Future.delayed(const Duration(seconds: 1));

    // ======================= END SIMULATING ESSENTIA ========================================

    if (!mounted) return; // Guard against using context if widget is disposed

    setState(() {
      _isProcessing = false;
    });

    // Move simulated results to visualizer page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Visualizer(
          audioName: audioName,
          audioUrl: assetPath,
          duration: duration,
          musicalKey: musicalKey,
          chromagram: chromagram,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Load assets"),
      ),
      body: Center(
        child: _isProcessing
            ? const CircularProgressIndicator()
            : SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ...audioNames.map(
                      (name) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: ElevatedButton(
                          onPressed: () => _loadAssetAndGoToVisualizer(name),
                          child: Text('Load "$name"'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
