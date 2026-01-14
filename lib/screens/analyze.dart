import 'package:flutter/material.dart';
import 'package:music_app/ffi/audioanalysis_ffi.dart' as audioffi;
import 'package:music_app/screens/visualize.dart';
import 'dart:io' show Platform;


class AnalyzePage extends StatefulWidget {
  const AnalyzePage({super.key, required this.audioUrl, required this.audioName});

  final String audioName; // name of the audio file
  final String audioUrl; // audio path for archive audio

  @override
  State<AnalyzePage> createState() => _AnalyzePageState();
}

class _AnalyzePageState extends State<AnalyzePage> {
  bool _isLoading = false;
  String? _error;

  Future<void> _analyzeAndNavigate() async {
    if (Platform.isAndroid) {
      throw UnimplementedError('Audio analysis is not implemented on Android.');
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = audioffi.AudioProcessingFfi().loadAndAnalyze(widget.audioUrl);
      if (result['key'] == null || result['duration'] == null || result['chromagram'] == null) {
        throw Exception('Analysis failed or incomplete.');
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Visualizer(
            audioName: widget.audioName,
            audioUrl: widget.audioUrl,
            duration: result['duration'] as double,
            musicalKey: result['key'] as String,
            chromagram: result['chromagram'] as List<List<double>>,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Analyze: ${widget.audioName}'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Audio URL: ${widget.audioUrl}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _analyzeAndNavigate,
              child: _isLoading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Analyze and Visualize'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }
}

