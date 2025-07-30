import 'package:flutter/material.dart';

class AnalyzePage extends StatefulWidget {
  const AnalyzePage({super.key, required this.audioUrl});

  final String audioUrl;

  @override
  State<AnalyzePage> createState() => _AnalyzePageState();
}

class _AnalyzePageState extends State<AnalyzePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text("TITLE OF PAGE"),
      ),
      body: Center(child: Text("Analyze audio ${widget.audioUrl}")),
    );
  }
}
