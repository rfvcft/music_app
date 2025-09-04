import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle; // for access to assets



class AnalyzePage extends StatelessWidget {
  const AnalyzePage({super.key, required this.audioUrl});

  final String audioUrl; // audio path for archive audio. Will eventually be processed by Essentia

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analyze'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Audio URL: $audioUrl', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            const Text('Analysis not implemented yet.', style: TextStyle(fontSize: 18, color: Colors.red)),
          ],
        ),
      ),
    );
  }
}

