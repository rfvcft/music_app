import 'package:flutter/material.dart';

class AnalyzePage extends StatefulWidget {
  const AnalyzePage({super.key, required this.audioUrl});

  final String audioUrl;

  @override
  State<AnalyzePage> createState() => _AnalyzePageState();
}

class _AnalyzePageState extends State<AnalyzePage> {
  bool _isProcessing = false;
  String? _errorMessage;
  String? _analysisResult;

  Future<void> _processAudio() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _analysisResult = null;
    });

    try {
      // TODO: Call your C++ backend here via Platform Channels
      // For now, simulate analysis delay:
      await Future.delayed(const Duration(seconds: 2));

      // Simulated result
      String result = "(SIMULATED) Detected Key: C Major";

      setState(() {
        _isProcessing = false;
        _analysisResult = result;
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Failed to process audio: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text("Analyze Audio"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, 
          children: [
            Text("Audio path: ${widget.audioUrl}"),
            const SizedBox(height: 20),
            _isProcessing
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _processAudio,
                    child: const Text('Analyze Audio'),
                  ),
            const SizedBox(height: 20),
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            if (_analysisResult != null)
              Text(
                _analysisResult!,
                style: const TextStyle(color: Colors.green, fontSize: 18),
              ),
          ],
        ),
      ),
    );
  }
}
