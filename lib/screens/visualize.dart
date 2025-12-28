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
    if (!mounted) return;
    await _player.seek(Duration(milliseconds: (initialTime * 1000).toInt()));
    await _player.resume();
    if (!_ticker.isActive) {
      _ticker.start();
    }
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
      if (!mounted) return;
      setState(() {
        currentTime = initialTime + elapsed.inMilliseconds / 1000.0;
        if (currentTime >= widget.duration) {
          currentTime = 0.0;
          pause();
        }
      });
    });

    _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {});
    });

    _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {});
      _ticker.stop();
    });

    _player.setSource(_resolveSource(widget.audioUrl));
  }

  @override
  void dispose() {
    _ticker.stop();    // <--- Stop the ticker first!
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;
          final availableHeight = constraints.maxHeight;

          double oneSecondPx = availableHeight / 6; // One second in pixels
          double durationPx = widget.duration * oneSecondPx; // Total duration in pixels
          double currentTimePx = currentTime * oneSecondPx; // Current time in pixels

          double currentLinePx = availableHeight * (1/3); // Distance of current line from bottom 
          double pitchLinePx = currentLinePx - oneSecondPx; // Distance of pitch line from bottom 
          double deltaWidthPx = availableWidth / 15; // Horizontal offset for vertical lines (x coord difference)


          List<Widget> baseWidgets = [];
          Widget playButton = PlayButton(
                  isPlaying: isPlaying,
                  onPressed: () {
                    if (isPlaying) {
                      pause();
                    } else {
                      play();
                    }
                  },
                );
          
          Widget keyDurationInfo = Positioned(
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
                );
          
          Widget currentLine = Positioned(
                  bottom: currentLinePx, 
                  left: deltaWidthPx,
                  right: deltaWidthPx,
                  child: Container(
                    height: 1, 
                    color: Colors.pink,
                  ),
                );
          
          Widget pitchLine = Positioned(
                  bottom: pitchLinePx, 
                  left: deltaWidthPx,
                  right: deltaWidthPx,
                  child: Container(
                    height: 1, 
                    color: Colors.grey,
                  ),
                );
          baseWidgets.addAll([currentLine, pitchLine, keyDurationInfo, playButton]);

          for (int i = 1; i <= 12; i++) {
            Widget verticalPitchLine = Positioned(
              left: (i + 1) * deltaWidthPx,
              top: 0,
              bottom: pitchLinePx,
              child: Container(
                width: 1,
                color: Colors.grey,
              ),
            );
            baseWidgets.add(verticalPitchLine);
          }

          List<Widget> dynamicWidgets = [];
          Widget timeAxis = Positioned(
                  left: availableWidth / 2, 
                  bottom: currentLinePx,
                  child: Transform.translate(
                    offset: Offset(0, currentTimePx),
                    child: Container(
                      width: 1,
                      height: durationPx,
                      color: Colors.purple,
                    ),
                  ),
                ); 

          Widget intensityBar = Positioned(
                  left: availableWidth / 2 + 40,
                  bottom: currentLinePx, 
                  child: Transform.translate(
                    offset: Offset(0, currentTimePx), 
                    child: IntensityBar(
                      values: widget.chromagram[0],
                      width: 10, 
                      height: durationPx,
                    ),
                  ),
                );
          dynamicWidgets.addAll([timeAxis, intensityBar]);
            
          for (int i = 0; i < 12; i++) {
            double width = deltaWidthPx / 2;
            Widget pitchIntensityBar = Positioned(
              left: (13 - i) * deltaWidthPx - width / 2,
              bottom: currentLinePx, 
              child: Transform.translate(
                offset: Offset(0, currentTimePx), 
                child: IntensityBar(
                  values: widget.chromagram[i],
                  width: width, 
                  height: durationPx,
                ),
              ),
            );
            dynamicWidgets.add(pitchIntensityBar);
          }

          List<Widget> allWidgets = dynamicWidgets + baseWidgets;
          return SizedBox.expand(
            child: Stack(
              children: allWidgets,
            ),
          );
        },
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

class IntensityBar extends StatelessWidget {
  final List<double> values; // values in range 0..1
  final double width;
  final double height;

  const IntensityBar({
    super.key,
    required this.values,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _IntensityBarPainter(values),
    );
  }
}

class _IntensityBarPainter extends CustomPainter {
  final List<double> values;

  _IntensityBarPainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    final rectWidth = size.width;
    final rectHeight = size.height / values.length;
    for (int i = 0; i < values.length; i++) {
      final intensity = values[i].clamp(0.0, 1.0);
      final color = Color.lerp(Colors.white, Colors.black, intensity)!;
      final rect = Rect.fromLTWH(
        0, // left
        (values.length - 1 - i)*rectHeight,     // top
        rectWidth,    // width of rect
        rectHeight,   // height of rect
      );
      final paint = Paint()..color = color;
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _IntensityBarPainter oldDelegate) =>
      oldDelegate.values != values;
}





