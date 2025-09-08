import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

  @override
  State<Visualizer> createState() => _VisualizerState();
}

class _VisualizerState extends State<Visualizer> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text("Chromagram visualizer"),
      ),
      body: Stack(
        children: [
          // 👇 You can add your actual visualization widget here later
          const Center(child: Text("Your chromagram visualization goes here")),
          // Audio player
          SimpleAudioPlayer(audioUrl: widget.audioUrl),
          // Show key and duration
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
                  'Dimensions of chromagram: (${widget.chromagram.length}, ${widget.chromagram[0].length})',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SimpleAudioPlayer extends StatefulWidget {
  final String audioUrl;

  const SimpleAudioPlayer({super.key, required this.audioUrl});

  @override
  State<SimpleAudioPlayer> createState() => _SimpleAudioPlayerState();
}

class _SimpleAudioPlayerState extends State<SimpleAudioPlayer> {
  final ap.AudioPlayer _player = ap.AudioPlayer()..setReleaseMode(ap.ReleaseMode.stop);

  @override
  void setState(VoidCallback fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((state) {
      setState(() {});
    });

    _player.onPlayerComplete.listen((_) {
      setState(() {});
    });

    _player.setSource(_resolveSource(widget.audioUrl));
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _player.state == ap.PlayerState.playing;

    return IconButton(
      icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
      iconSize: 48,
      onPressed: () {
        if (isPlaying) {
          _player.pause();
        } else {
          _player.play(_resolveSource(widget.audioUrl));
        }
      },
    );
  }

  ap.Source _resolveSource(String path) {
    if (path.startsWith('assets/')) {
      // audioplayers requires asset paths without the "assets/" prefix
      return ap.AssetSource(path.replaceFirst('assets/', ''));
    } else {
      return kIsWeb ? ap.UrlSource(path) : ap.DeviceFileSource(path);
    }
  }
}
