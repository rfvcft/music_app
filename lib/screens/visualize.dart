import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:music_app/screens/settings.dart';

class Visualizer extends StatefulWidget {
  Visualizer({
    super.key,
    required this.audioName,
    required this.audioUrl,
    required this.duration,
    required this.musicalKey,
    required this.chromagram,
  })  : numPitches = chromagram.length,
        numFrames = chromagram[0].length;

  final String audioName; // Name of the audio file (without extension)
  final String audioUrl; // URL or asset path to audio file
  final double duration; // Duration of audio in seconds (computed by C++ library)
  final String musicalKey; // Musical key of the audio
  final List<List<double>> chromagram; // Chromagram: List of 12 pitch classes, each with intensity values over time frames

  final int numPitches; // number of pitch classes (12)
  final int numFrames; // number of time frames (proportional to duration)

  @override
  State<Visualizer> createState() => _VisualizerState();
}

class _VisualizerState extends State<Visualizer> with SingleTickerProviderStateMixin {
  
  double currentTime = 0.0; // Current time in seconds. Visuals are based on this variable.

  late double _flingVelocity; // Velocity of fling in seconds per second
  late Ticker _flingTicker; // Ticker for fling animation
  late double _initialTime; // Auxilliary variable used for starting fling ticker
  late bool _resumePlayingLater; // Track if playback should resume after scrolling
  bool isFlinging = false; // Track whether a fling animation is in progress

  final ap.AudioPlayer _player = ap.AudioPlayer()..setReleaseMode(ap.ReleaseMode.stop); // Audio player
  double _duration = 0.0; // Duration of audio file in seconds
  bool isPlaying = false; // Track whether audio/visuals are playing

  bool get isComplete => (currentTime >= _duration); // Track whether audio has completed playing

  // Initialize states
  @override
  void initState() {
    super.initState();
    // Initialize fling ticker
    _flingTicker = Ticker(_flingUpdate);

    // Listen for duration changes and set _duration
    _player.onDurationChanged.listen((Duration duration) {
      if (!mounted) return;
      setState(() {
        _duration = duration.inMilliseconds / 1000.0; // store duration in seconds
      });
    });

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

    // When audio completes, update playing state, set currentTime to duration and redraw UI
        _player.onPlayerComplete.listen((_) {
          if (!mounted) return;
          setState(() {
            isPlaying = false;
            currentTime = _duration; 
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
    await _player.seek(Duration(milliseconds: (currentTime * 1000).toInt()));
    await _player.resume();
    setState(() {
      isPlaying = true;
    });
  }

  // Pause audio and visualization
  void pause() {
    _player.pause();
    setState(() {
      isPlaying = false;
    });
  }

  // Resets playback to the start and pauses audio
  void reset() {
    currentTime = 0.0;
    pause();
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
    if (_resumePlayingLater) play();
  }

  // Update current time based on fling velocity. To be called by fling ticker
  void _flingUpdate(Duration elapsed) {
    if (!isFlinging) return;

    // Exponential decay model for fling
    const double dampingFactor = 4.0;
    double timeDelta = (_flingVelocity / dampingFactor) * (1 - exp(-dampingFactor * elapsed.inMilliseconds / 1000.0));
    double timeDeltaLimit = (_flingVelocity / dampingFactor); 
    double timeDiff = (timeDeltaLimit - timeDelta).abs();

    if (!mounted) return;
    setState(() {
      // Update currentTime based on fling velocity and elapsed time
      currentTime = _initialTime + timeDelta; 
      
      // Clamp currentTime within valid range and end fling if limits are reached or velocity is low
      if (currentTime < 0.0) {
        currentTime = 0.0;
        _endFling();
        return;
      } 
      if (currentTime > _duration) {
        currentTime = _duration;
        pause();
        _abortFling();
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
    if (_duration == 0.0) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.audioName,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth; 
          final availableHeight = constraints.maxHeight; 

          const double goldenRatio = 1.6180339887; // Golden ratio = (1 + sqrt(5)) / 2
          const double goldenFactorSmall = 1 / (goldenRatio + 1); // Smaller golden section
          const double goldenFactorLarge = goldenRatio / (goldenRatio + 1); // Larger golden section

          double heightAboveCurrent = goldenFactorLarge * availableHeight; // Available height above current line
          double heightBelowCurrent = goldenFactorSmall * availableHeight; // Available height below current line

          const int numSecondsAboveCurrent = 5; // Number of seconds to display above current time
          double oneSecondPx = heightAboveCurrent / numSecondsAboveCurrent; // One second in pixels
          double durationPx = _duration * oneSecondPx; // Total duration in pixels
          double currentTimePx = currentTime * oneSecondPx; // Current time in pixels

          double currentLinePx = heightBelowCurrent; // Distance of current line from bottom of screen
          double sliderLinePx = goldenFactorLarge * heightBelowCurrent; // Distance of slider line from bottom of screen

          const int numPitches = 12; // Number of pitch classes
          double deltaWidthPx = availableWidth / (2 + numPitches - 1 + 2); // Horizontal offset for vertical lines 
          double deltaHeightPx = goldenFactorLarge * (currentLinePx - sliderLinePx); // Vertical offset between current line and bottom line 

          double bottomLinePx = currentLinePx - deltaHeightPx; // Distance of bottom line from bottom of screen 

          List<Widget> allWidgets = [];

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
            allWidgets.add(pitchIntensityBar);
          }

          // 12 vertical lines, C (rightmost) to B (leftmost)
          for (int i = 1; i <= 12; i++) {
            Widget verticalPitchLine = Positioned(
              left: (i + 1) * deltaWidthPx,
              bottom: currentLinePx,
              child: Transform.translate(
                offset: Offset(0, currentTimePx), 
                child: Container(
                  width: 1,
                  height: durationPx,
                  color: Colors.grey,
                ),
              ),
            );
            allWidgets.add(verticalPitchLine);
          }


          // Start horizontal line
          Widget startLine = Positioned(
            left: 2*deltaWidthPx,
            right: 2*deltaWidthPx,
            bottom: currentLinePx,
            child: Transform.translate(
              offset: Offset(0, min(currentTimePx, deltaHeightPx)), 
              child: Container(
                height: 1,
                color: Colors.grey,
              ),
            ),
          );
          allWidgets.add(startLine);

          // Estimated key text below the start line
          const double fadeOutTime = 1.0;
          double keyTextOpacity = (1 - (currentTime / fadeOutTime)).clamp(0.0, 1.0);
          Widget estimatedKeyText = Positioned(
            left: 2*deltaWidthPx,
            right: 2*deltaWidthPx,
            bottom: currentLinePx - 0.35 * oneSecondPx,
            child: Transform.translate(
              offset: Offset(0, min(currentTimePx, deltaHeightPx)),
              child: Opacity(
                opacity: keyTextOpacity,
                child: Text(
                  'Key: ${widget.musicalKey}',
                  textAlign: TextAlign.left,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          );
          allWidgets.add(estimatedKeyText);

          // End horizontal line
          Widget endLine = Positioned(
            left: 2*deltaWidthPx,
            right: 2*deltaWidthPx,
            bottom: currentLinePx + durationPx,
            child: Transform.translate(
              offset: Offset(0, currentTimePx), 
              child: Container(
                height: 1,
                color: Colors.grey,
              ),
            ),
          );
          allWidgets.add(endLine);

          // Blocker to cover chroma bars below pitch line
          Widget chromaBlocker = Positioned(
            top: availableHeight - bottomLinePx,
            left: 0,
            right: 0,
            child: Container(
              height: availableHeight,
              color: Colors.black,
            ),
          );
          allWidgets.add(chromaBlocker);

          // Pitch class names from C to B
          const List<String> pitchClassNames = [
            'C', 'C#', 'D', 'D#', 'E', 'F',
            'F#', 'G', 'G#', 'A', 'A#', 'B'
          ];

          for (int i = 1; i <= 12; i++) {
            // Add pitch class label below startLine, translated with currentTimePx
            Widget pitchLabel = Positioned(
              left: (i + 1) * deltaWidthPx - 16, // Center label under line
              bottom: currentLinePx - 18,
              child: Transform.translate(
                offset: Offset(0, min(currentTimePx, deltaHeightPx)),
                child: SizedBox(
                  width: 32,
                  child: Center(
                    child: Text(
                      pitchClassNames[12 - i],
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ),
            );
            allWidgets.add(pitchLabel);
          }

          // Current position of audio playback
          Widget currentLine = Positioned(
            // Align the center of the line with currentLinePx
            bottom: currentLinePx,
            left: deltaWidthPx,
            right: deltaWidthPx,
            child: Container(
              height: 1, // Originally 1
              color: Colors.white,
            ),
          );
          allWidgets.add(currentLine);

          // Right arrow icon at current position
          double iconSize = 30;
          Widget rightArrow = Positioned(
            bottom: currentLinePx - iconSize / 2 + 0.5, // +0.5 shift to center (experimentally determined)
            left: deltaWidthPx / 2,
            child: Icon(
              Icons.play_arrow,
              color: Colors.white,
              size: iconSize,
            ),
          );
          allWidgets.add(rightArrow);

          // Place play button centered below the pitch line
          Widget playButton = Positioned(
            left: 0,
            right: 0,
            bottom: availableHeight * 0.075, 
            child: Center(child: _playButton()),
          );
          allWidgets.add(playButton);

          // Slider to indicate and control playback time
          double radius = 8;
          Widget playbackSlider = Positioned(
            left: deltaWidthPx - radius,
            right: deltaWidthPx - radius,
            bottom: sliderLinePx -radius,
            child: _playbackSlider(radius: radius),
          );
          allWidgets.add(playbackSlider);

          // Widget to display current time and total duration 
          Widget timeDisplay = Positioned(
            left: deltaWidthPx,
            right: deltaWidthPx,
            bottom: availableHeight * 0.13, 
            child: _timeDisplay(),
          );
          allWidgets.add(timeDisplay);
          
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragStart: (_) {
              // If fling in progress, abort it
              if (isFlinging) {
                _abortFling();
                return;
              }
              
              // If audio was playing, pause and set _resumePlayingLater
              if (isPlaying) { 
                _resumePlayingLater = true;
                pause();
                return;
              } 

              _resumePlayingLater = false;
            },
            onVerticalDragUpdate: (details) {
              if (!mounted) return;
              setState(() {
                // Adjust currentTime: finger moving down -> positive delta -> increase time
                currentTime += details.primaryDelta! / oneSecondPx;
                currentTime = currentTime.clamp(0.0, _duration); 
              });
            },
            onVerticalDragEnd: (details) {
              // Fling effect
              _flingVelocity = (details.primaryVelocity ?? 0.0) / oneSecondPx; // Convert pixels per second to seconds per second
              _startFling(); // Start fling animation (needs _flingVelocity to be set)
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


  // Returns the appropriate play/pause/replay button widget
  Widget _playButton() {
    Color iconColor = Colors.black;
    Color backgroundColor = Colors.white;
    double radius = 30;
    double iconSize = 38;

    if (isComplete) {
      // Show "go to start" button when playback is complete
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor,
        child: IconButton(
          icon: const Icon(Icons.replay),
          iconSize: iconSize,
          color: iconColor,
          onPressed: reset,
        ),
      );
    } else {
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor,
        child: IconButton(
          icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
          iconSize: iconSize,
          color: iconColor,
          onPressed: () {
            if (isFlinging) _abortFling();
            if (isPlaying) {
              pause();
            } else {
              play();
            }
          },
        ),
      );
    }
  }

  // Widget to display current time and total duration aligned with slider ends
  Widget _timeDisplay() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _formatTime(currentTime),
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
        Text(
          _formatTime(_duration),
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ],
    );
  }

  // Returns the playback slider widget (no time display, no positioning)
  Widget _playbackSlider({double radius = 11}) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackShape: const RoundedRectSliderTrackShape(),
        trackHeight: 3,
        overlayShape: SliderComponentShape.noOverlay,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: radius),
      ),
      child: Slider(
        value: currentTime.clamp(0.0, _duration),
        min: 0.0,
        max: _duration,
        onChanged: (value) {
          // Update currentTime as slider is moved
          if (!mounted) return;
          setState(() {
            currentTime = value;
          });
        },
        onChangeStart: (value) {
          // If fling in progress, abort it
          if (isFlinging) _abortFling();
          // If audio was playing, pause and set _resumePlayingLater
          if (isPlaying) {
            _resumePlayingLater = true;
            pause();
          } else {
            _resumePlayingLater = false;
          }
        },
        onChangeEnd: (value) {
          // Resume audio if it was playing before
          if (_resumePlayingLater) {
            play();
          }
        },
        activeColor: Colors.white,
        inactiveColor: Colors.grey,
      ),
    );
  }

  // Add this helper method to your _VisualizerState class:
  String _formatTime(double seconds) {
    final int min = seconds ~/ 60;
    final int sec = seconds.toInt() % 60;
    // Only show leading zero for minutes if time is 10 minutes or more
    if (min < 10) {
      return '$min:${sec.toString().padLeft(2, '0')}';
    } else {
      return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
    }
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
      if (intensity < 0.1) continue; // Skip very low intensities for performance
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





