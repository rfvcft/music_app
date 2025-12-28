import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:audioplayers/audioplayers.dart' as ap;

class Visualizer extends StatefulWidget {
  const Visualizer({
    super.key,
    required this.audioUrl,
    required this.duration,
    required this.musicalKey,
    required this.chromagram,
  });

  final String audioUrl;
  final double duration;
  final String musicalKey;
  final List<List<double>> chromagram;

  int get numPitches => chromagram.length;
  int get numFrames => chromagram[0].length;

  final double visualLengthSecond = 144.0;
  double get visualLengthTotal => duration * visualLengthSecond;

  @override
  State<Visualizer> createState() => _VisualizerState();
}

class _VisualizerState extends State<Visualizer> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double currentTime = 0.0;
  double initialTime = 0.0;
  double get visualCurrentTime => currentTime * widget.visualLengthSecond;

  final ap.AudioPlayer _player = ap.AudioPlayer()..setReleaseMode(ap.ReleaseMode.stop);

  void play() async {
    await _player.seek(Duration(milliseconds: (initialTime * 1000).toInt()));
    await _player.resume();
    _ticker.start();
  }

  void pause() {
    initialTime = currentTime;
    _ticker.stop();
    _player.pause();
  }

  @override
  void initState() {
    super.initState();
    _ticker = Ticker((elapsed) {
      setState(() {
        currentTime = initialTime + elapsed.inMilliseconds / 1000.0;
        if (currentTime >= widget.duration) {
          currentTime = 0.0;
          pause();
        }
      });   
    });

    _player.onPlayerStateChanged.listen((state) {
      setState(() {});
    });

    _player.onPlayerComplete.listen((_) {
      setState(() {});
      _ticker.stop();
    });

    _player.setSource(_resolveSource(widget.audioUrl));
  }

  @override
  void dispose() {
    _ticker.dispose();
    _player.dispose();
    super.dispose();
  }

  ap.Source _resolveSource(String path) {
    if (path.startsWith('assets/')) {
      return ap.AssetSource(path.replaceFirst('assets/', ''));
    } else {
      return kIsWeb ? ap.UrlSource(path) : ap.DeviceFileSource(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _player.state == ap.PlayerState.playing;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text("Chromagram visualizer"),
      ),
      body: SizedBox.expand(
        child: Stack(
          children: [
            // Play button (top left by default)
            PlayButton(
              isPlaying: isPlaying,
              onPressed: () {
                if (isPlaying) {
                  pause();
                } else {
                  play();
                }
              },
            ),
            // Show key and duration (top right)
            Positioned(
              top: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Key: ${widget.musicalKey}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  Text(
                    'Duration: ${widget.duration.toStringAsFixed(2)} s',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  Text(
                    'Dimensions of chromagram: (${widget.numPitches}, ${widget.numFrames})',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
            // --- Current position of audio (green horizontal line) ---
            HorizontalLine(
              bottomOffset: 244,
              color: Colors.green,
            ),
            VerticalLine(
              visualLengthTotal: widget.visualLengthTotal,
              translateOffset: visualCurrentTime,
              color: Colors.blue,
            ),
            // --- Bottom line of visualization (grey horizontal line) ---
            HorizontalLine(
              bottomOffset: 244 - widget.visualLengthSecond,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}

class HorizontalLine extends StatelessWidget {
  final double bottomOffset;
  final Color color;

  const HorizontalLine({
    super.key,
    required this.bottomOffset,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: bottomOffset,
      child: Container(
        height: 1,
        color: color,
      ),
    );
  }
}

class VerticalLine extends StatelessWidget {
  final double visualLengthTotal;
  final double translateOffset;
  final Color color;
  
  const VerticalLine({
    super.key,
    required this.visualLengthTotal,
    required this.translateOffset,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: MediaQuery.of(context).size.width / 2, 
      bottom: 244,
      height: visualLengthTotal,
      child: Transform.translate(
        offset: Offset(0, translateOffset), 
        child: Container(
          width: 1,
          color: color,
        ),
      ),
    );
  }
}

class PlayButton extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPressed;

  const PlayButton({
    super.key,
    required this.isPlaying,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
      iconSize: 48,
      onPressed: onPressed,
    );
  }
}





