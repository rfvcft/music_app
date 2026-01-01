import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:audioplayers/audioplayers.dart' as ap;

class Visualizer extends StatefulWidget {
  Visualizer({
    super.key,
    required this.audioUrl,
    required this.duration,
    required this.musicalKey,
    required this.chromagram,
  })  : numPitches = chromagram.length,
        numFrames = chromagram[0].length;

  final String audioUrl; // URL or asset path to audio file
  final double duration; // Duration of audio in seconds
  final String musicalKey; // Musical key of the audio
  final List<List<double>> chromagram; // Chromagram: List of 12 pitch classes, each with intensity values over time frames

  final int numPitches; // number of pitch classes (12)
  final int numFrames; // number of time frames (proportional to duration)

  @override
  State<Visualizer> createState() => _VisualizerState();
}

class _VisualizerState extends State<Visualizer> with SingleTickerProviderStateMixin {
  
  double currentTime = 0.0; // Current time in seconds. Visuals are based on this variable.
  bool isPlaying = false; // Track whether audio/visuals are playing

  late double _flingVelocity; // Velocity of fling in seconds per second
  late Ticker _flingTicker; // Ticker for fling animation
  late double _initialTime; // Auxilliary variable used for starting fling ticker
  late bool _resumePlayingAfterFling; // Track if playback should resume after scrolling
  bool isFlinging = false; // Track whether a fling animation is in progress

  final ap.AudioPlayer _player = ap.AudioPlayer()..setReleaseMode(ap.ReleaseMode.stop); // Audio player

  // Initialize states
  @override
  void initState() {
    super.initState();
    // Initialize fling ticker
    _flingTicker = Ticker(_flingUpdate);

    // Synchronize currentTime with audio player position and redraw UI if player is active
    _player.onPositionChanged.listen((Duration position) {
      if (!mounted) return;
      if (isPlaying) {
        setState(() {
          currentTime = position.inMilliseconds / 1000.0;
        });
      }
    });

    // Redraw UI on player state changes
    _player.onPlayerStateChanged.listen((state) { 
      if (!mounted) return;
      setState(() {});
    });

    // When audio competes, update playing state, set currentTime to duration and redraw UI
    _player.onPlayerComplete.listen((_) { 
      if (!mounted) return;
      setState(() {
        isPlaying = false;
        currentTime = widget.duration;
      });
    });
    _player.setSource(_resolveSource(widget.audioUrl)); // Set audio source
  }

  // Clean up resources
  @override
  void dispose() {   
    _flingTicker.dispose();
    _player.dispose();
    super.dispose();
  }

  // Play audio and start visualization
  Future<void> play() async {
    await _player.seek(Duration(milliseconds: (currentTime * 1000).toInt())); // Position audio to current time
    await _player.resume(); // Start audio playback. This will also start the visualization via the position listener

    isPlaying = true; // Update playing state
  }

  // Pause audio and visualization
  void pause() {
    _player.pause(); // Pause audio playback. This will also pause the visualization via the position listener
    
    isPlaying = false; // Update playing state
  }

  // Resolve audio source based on path type (asset, URL, or device file)
  ap.Source _resolveSource(String path) {
    if (path.startsWith('assets/')) {
      return ap.AssetSource(path.replaceFirst('assets/', ''));
    } else {
      return kIsWeb ? ap.UrlSource(path) : ap.DeviceFileSource(path);
    }
  }

  // Start fling animation
  void _startFling() {
    _initialTime = currentTime; // Fix initial time for fling ticker updates
    _flingTicker.start(); // Start fling by starting ticker. See _flingUpdate for details 
    isFlinging = true;
  }

  // Abort fling animation
  void _abortFling() {
    _flingTicker.stop(); // Stop fling by stopping ticker
    isFlinging = false;
  }

  // End fling animation and resume playback if needed
  void _endFling() {
    _abortFling();
    if (_resumePlayingAfterFling) play();
  }

  // Update current time based on fling velocity. To be called by fling ticker
  void _flingUpdate(Duration elapsed) {
    if (!isFlinging) return;

    // Fling motion is modelled by a decaying exponential velocity function with initial velocity _flingVelocity
    const double dampingFactor = 4.0;
    double timeDelta = (_flingVelocity / dampingFactor) * (1 - exp(-dampingFactor * elapsed.inMilliseconds / 1000.0));
    double timeDeltaLimit = (_flingVelocity / dampingFactor); 
    double timeDiff = (timeDeltaLimit - timeDelta).abs();

    if (!mounted) return;
    setState(() {
      currentTime = _initialTime + timeDelta; 
      if (currentTime < 0.0) {
        currentTime = 0.0;
        _endFling();
        return;
      } 
      if (currentTime > widget.duration) {
        currentTime = widget.duration;
        _endFling();
        return;
      } 
      if (timeDiff < 0.1) {
        _endFling();
        return;
      } 
    }); 
  }

  // Build the visualization UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chromagram Visualizer"),
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
          Widget playButton = IconButton(
                  icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                  iconSize: 48,
                  onPressed: () {
                    if (isFlinging) _abortFling();
                    if (isPlaying) {
                      pause();
                    } else {
                      play();
                    }
                  },
                );
          
          // Current position of audio playback
          Widget currentLine = Positioned(
                  bottom: currentLinePx, 
                  left: deltaWidthPx,
                  right: deltaWidthPx,
                  child: Container(
                    height: 5, // Originally 1
                    color: Colors.white,
                  ),
                );
          
          // Position of pitch line (bottom line of visualization)
          Widget pitchLine = Positioned(
                  bottom: pitchLinePx, 
                  left: deltaWidthPx,
                  right: deltaWidthPx,
                  child: Container(
                    height: 1, 
                    color: Colors.grey,
                  ),
                );

          // Blocker to cover chroma bars below pitch line
          Widget chromaBlocker = Positioned(
            top: availableHeight - pitchLinePx,
            left: 0,
            right: 0,
            child: Container(
              height: availableHeight,
              color: Colors.black,
            ),
          );

          baseWidgets.addAll([currentLine, pitchLine, playButton, chromaBlocker]);

          // Vertical lines for pitch classes
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
          // Reference time axis (for debugging)
          Widget timeAxis = Positioned(
                  left: availableWidth - deltaWidthPx / 2, 
                  bottom: currentLinePx,
                  child: Transform.translate(
                    offset: Offset(0, currentTimePx), // Translate vertically down based on current playback time
                    child: Container(
                      width: 1,
                      height: durationPx,
                      color: Colors.purple,
                    ),
                  ),
                ); 
          dynamicWidgets.add(timeAxis);
          
          // Chromagram pitch intensity bars
          for (int i = 0; i < 12; i++) {
            double width = deltaWidthPx / 2;
            Widget pitchIntensityBar = Positioned(
              left: (13 - i) * deltaWidthPx - width / 2,
              bottom: currentLinePx, 
              child: Transform.translate(
                offset: Offset(0, currentTimePx),  // Translate vertically down based on current playback time
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

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragStart: (_) {
              if (isFlinging) {
                _abortFling();
                return;
              }
              
              // Below, we want to resume playing if and only if the audio was playing before
              if (isPlaying) { 
                _resumePlayingAfterFling = true;
                pause();
                return;
              } 

              _resumePlayingAfterFling = false;
            },
            onVerticalDragUpdate: (details) {
              if (!mounted) return;
              setState(() {
                // Adjust currentTime: finger moving down -> positive delta -> increase time
                currentTime += details.primaryDelta! / oneSecondPx;
                currentTime = currentTime.clamp(0.0, widget.duration);
              });
            },
            onVerticalDragEnd: (details) {
              // Fling effect
              _flingVelocity = (details.primaryVelocity ?? 0.0) / oneSecondPx;
              _startFling();
            },
            child: SizedBox.expand(
              child: Stack(
                children: allWidgets,
              ),
            ),
          );
        },
      ),
    );
  }
}


// Sampled inferno colormap (10 points, you can add more for smoother gradients)
const List<Color> infernoColors = [
  Color(0xFF000004),
  Color(0xFF1B0C41),
  Color(0xFF4A0C6B),
  Color(0xFF781C6D),
  Color(0xFFA52C60),
  Color(0xFFCF4446),
  Color(0xFFF1605D),
  Color(0xFFFCA636),
  Color(0xFFFFDF4A),
  Color(0xFFFFFCB0),
];

Color infernoColormap(double t) {
  t = t.clamp(0.0, 1.0);

  final scaled = t * (infernoColors.length - 1);
  final idx = scaled.floor();
  final frac = scaled - idx;

  if (idx >= infernoColors.length - 1) {
    return infernoColors.last;
  }
  return Color.lerp(infernoColors[idx], infernoColors[idx + 1], frac)!;
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
      final color = infernoColormap(intensity);
      final rect = Rect.fromLTWH(
        0, // left
        (values.length - 1 - i) * rectHeight, // top
        rectWidth, // width of rect
        rectHeight, // height of rect
      );
      final paint = Paint()..color = color;
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _IntensityBarPainter oldDelegate) =>
      oldDelegate.values != values;
}





