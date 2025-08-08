import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle; // for access to assets

import 'package:music_app/screens/visualize.dart';


// Available options for backend simulator: 
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

class AnalyzePage extends StatefulWidget {
  const AnalyzePage({super.key, required this.audioUrl});

  final String audioUrl; // audio path for archive audio. Will eventually be processed by Essentia

  @override
  State<AnalyzePage> createState() => _AnalyzePageState();
}

class _AnalyzePageState extends State<AnalyzePage> {
  bool _isProcessing = false;
  

  Future<void> _analyzeAndGoToVisualizer(String audioName) async {
    setState(() {
      _isProcessing = true;
    });

    // ================ SIMULATING ESSENTIA =====================
    // Path to audio
    String assetPath = 'assets/analyzed_examples/input/${audioName}.m4a';
    print(assetPath);

    // Get key and duration of audio
    String meta = await rootBundle.loadString('assets/analyzed_examples/output/${audioName}/meta.csv');
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
    String hpcp = await rootBundle.loadString('assets/analyzed_examples/output/${audioName}/hpcp.csv');
    final List<List<double>> chromagram = [];

    final rows = hpcp.split('\n');
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
    Navigator.push(context, MaterialPageRoute(builder: (context) => Visualizer(
        audioUrl: assetPath,
        duration: duration, 
        musicalKey: musicalKey, 
        chromagram: chromagram,
      )));
  }
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text("Analyze Audio"),
      ),
      body: Center(
        child: _isProcessing
            ? const CircularProgressIndicator()
            : SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ...audioNames.map((name) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: ElevatedButton(
                            onPressed: () => _analyzeAndGoToVisualizer(name),
                            child: Text('Analyze "$name"'),
                          ),
                        )),
                  ],
                ),
              ),
      ),
    );
  }
}
