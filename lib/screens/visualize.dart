import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:audioplayers/audioplayers.dart' as ap; // Audio player package

import 'package:music_app/core/app_settings.dart'; // App settings
import 'package:music_app/screens/settings.dart'; // Settings page
import 'package:music_app/utils/intensity_bar.dart' as ib; // Intensity bar widget
import 'package:music_app/utils/conversion.dart' as conv; // Conversion utilities
import 'package:music_app/utils/constants.dart' as cnst; // Import constants


class Visualizer extends StatefulWidget {
  Visualizer({
    super.key,
    required this.audioName,
    required this.audioUrl,
    required this.duration,
    required this.musicalKey,
    required this.chromagram,
  }) : assert(chromagram.length == cnst.numPitches, 'Chromagram must have ${cnst.numPitches} pitch classes.'),
        numFrames = chromagram[0].length;

  final String audioName; // Name of the audio file (without extension)
  final String audioUrl; // URL or asset path to audio file
  final double duration; // Duration of audio in seconds (computed by C++ library)
  final String musicalKey; // Musical key of the audio
  final List<List<double>> chromagram; // Chromagram: List of 12 pitch classes, each with intensity values over time frames

  final int numFrames; // Number of time frames (proportional to duration)

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

  String _musicalKey = ''; // Musical key of the audio (may be edited by user)
  int _tonicIndex = -1; // Tonic index of the audio
  String _scale = ''; // Scale of the audio 

  // Initialize states
  @override
  void initState() {
    super.initState();
    // Initialize musical key
    _musicalKey = widget.musicalKey;
    var parsed = conv.parseMusicalKey(_musicalKey);
    _tonicIndex = parsed.$1;
    _scale = parsed.$2;

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
  void _startFling(double flingVelocity) {
    _flingVelocity = flingVelocity; // Set fling velocity
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

  Future<void> _editMusicalKey(BuildContext context) async {
    // Parse current key
    String currentTonic = cnst.pitchClassNames.first;
    String currentScale = cnst.scalePatterns.keys.first;
    final keyRegExp = RegExp(r'([A-G]#?|B)\s*(major|minor)', caseSensitive: false);
    final match = keyRegExp.firstMatch(_musicalKey);
    if (match != null) {
      currentTonic = match.group(1) ?? currentTonic;
      currentScale = match.group(2)?.toLowerCase() ?? currentScale;
    }

    String selectedTonic = currentTonic;
    String selectedScale = currentScale;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Key'),
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    flex: 1,
                    child: DropdownButton<String>(
                      value: selectedTonic,
                      isExpanded: true,
                      items: cnst.pitchClassNames.map((tonic) {
                        return DropdownMenuItem<String>(
                          value: tonic,
                          child: Text(tonic),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => selectedTonic = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    flex: 2,
                    child: DropdownButton<String>(
                      value: selectedScale,
                      isExpanded: true,
                      items: cnst.scalePatterns.keys.map((scale) {
                        return DropdownMenuItem<String>(
                          value: scale,
                          child: Text(scale[0].toUpperCase() + scale.substring(1)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => selectedScale = value);
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
    if (result == true) {
      setState(() {
        _musicalKey = '$selectedTonic $selectedScale';
        _tonicIndex = cnst.pitchClassNameToIndex[selectedTonic] ?? -1;
        _scale = selectedScale;
      });
    }
  }

  // Build the visualization UI
  @override
  Widget build(BuildContext context) {
    // Show loading indicator if duration is not yet initialized
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
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => SettingsPage()),
              );
              // After returning, call setState to rebuild with new settings
              setState(() {});
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth; 
          final availableHeight = constraints.maxHeight; 

          late double oneSecondPx; 
          List<Widget> allWidgets = [];

          final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
          
          if (isPortrait) {
            const int numSecondsAboveCurrent = 5; // Number of seconds to display above current time
            double heightAboveCurrent = cnst.goldenFactorLarge * availableHeight; // Available height above current line
            double heightBelowCurrent = cnst.goldenFactorSmall * availableHeight; // Available height below current line

            oneSecondPx = heightAboveCurrent / numSecondsAboveCurrent; // One second in pixels
            double durationPx = _duration * oneSecondPx; // Total duration in pixels
            double currentTimePx = currentTime * oneSecondPx; // Current time in pixels

            double currentLinePx = heightBelowCurrent; // Distance of current line from bottom of screen
            double sliderLinePx = cnst.goldenFactorLarge * heightBelowCurrent; // Distance of slider line from bottom of screen

            double deltaWidthPx = availableWidth / (2 + cnst.numPitches - 1 + 2); // Horizontal offset for vertical lines 
            double deltaHeightPx = cnst.goldenFactorLarge * (currentLinePx - sliderLinePx); // Vertical offset between current line and bottom line 

            double bottomLinePx = currentLinePx - deltaHeightPx; // Distance of bottom line from bottom of screen 
            double chromaBlockerPx = availableHeight - bottomLinePx; // Height of chroma blocker from top of screen

            double playButtonPx = (availableHeight - sliderLinePx) + 0.1 * sliderLinePx; // Distance of top of audio player to top of screen
            double timeDisplayPx = (availableHeight - sliderLinePx) + 0.05 * sliderLinePx; // Distance of top of time display to top of screen
            double pitchLabelPx = (availableHeight - currentLinePx);
            double keyTextPx = (availableHeight - currentLinePx) + 0.075 * currentLinePx; // Distance of key text from top of screen

            // Chromagram pitch intensity bars
            for (int i = 0; i < cnst.numPitches; i++) {
              double width = deltaWidthPx / 2;
              Widget pitchIntensityBar = Positioned(
                left: (i + 2) * deltaWidthPx - width / 2,
                bottom: currentLinePx, 
                child: Transform.translate(
                  offset: Offset(0, currentTimePx),  // Translate vertically down based on current playback time
                  child: ib.IntensityBar(
                    values: widget.chromagram[(i + _tonicIndex) % cnst.numPitches],
                    orientation: 'vertical',
                    width: width, 
                    height: durationPx,
                  ),
                ),
              );
              allWidgets.add(pitchIntensityBar);
            }

            // 12 vertical lines for pitch classes
            for (int i = 1; i <= cnst.numPitches; i++) {
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
            double fadeOutTime = 0.5 * (deltaHeightPx / oneSecondPx); // Time in seconds over which text fades out
            double keyTextOpacity = (1 - (currentTime / fadeOutTime)).clamp(0.0, 1.0);
            Widget keyText = Positioned(
              left: 2*deltaWidthPx,
              right: 2*deltaWidthPx,
              top: keyTextPx,
              child: Transform.translate(
                offset: Offset(0, min(currentTimePx, deltaHeightPx)),
                child: Opacity(
                  opacity: keyTextOpacity,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Key: ',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.normal),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () => _editMusicalKey(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey[850],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _musicalKey,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
            allWidgets.add(keyText);

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
              top: chromaBlockerPx,
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black,
              ),
            );
            allWidgets.add(chromaBlocker);

            for (int i = 0; i < cnst.numPitches; i++) {
              // Add pitch class label below startLine, translated with currentTimePx
              // Determine if pitch is in scale
              final scalePattern = cnst.scalePatterns[_scale];
              final isInScale = scalePattern != null && scalePattern[i] == 1;
              Widget pitchLabel = Positioned(
                left: (i + 2) * deltaWidthPx - 16, // Center label under line
                top: pitchLabelPx,
                child: Transform.translate(
                  offset: Offset(0, min(currentTimePx, deltaHeightPx)),
                  child: SizedBox(
                    width: 32,
                    child: Center(
                      child: Text(
                        AppSettings.instance.showPitchClasses ? cnst.pitchClassNames[(i + _tonicIndex) % cnst.numPitches] : cnst.scaleDegrees[i],
                        style: TextStyle(
                          color: isInScale ? Colors.white : Colors.grey,
                          fontSize: 12,
                          fontWeight: isInScale ? FontWeight.bold : FontWeight.normal,
                        ),
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

            // Play button below the slider line
            double playButtonRadius = 30;
            double playButtonIconSize = 38;
            Widget playButton = Positioned(
              left: 0,
              right: 0,
              top: playButtonPx, 
              child: Center(child: _playButton(radius: playButtonRadius, iconSize: playButtonIconSize)),
            );
            allWidgets.add(playButton);

            // Slider to indicate and control playback time
            double sliderRadius = 8;
            Widget playbackSlider = Positioned(
              left: deltaWidthPx - sliderRadius,
              right: deltaWidthPx - sliderRadius,
              bottom: sliderLinePx -sliderRadius,
              child: _playbackSlider(radius: sliderRadius),
            );
            allWidgets.add(playbackSlider);

            // Widget to display current time and total duration 
            Widget timeDisplay = Positioned(
              left: deltaWidthPx,
              right: deltaWidthPx,
              top: timeDisplayPx, 
              child: _timeDisplay(),
            );
            allWidgets.add(timeDisplay);
        
          } else {
            double widthToRightOfCurrent = (3 / 4) * availableWidth; // Available width to the right of current line
            double widthToLeftOfCurrent = (1 / 4) * availableWidth; // Available width to the left of current line

            const int numSecondsToRightOfCurrent = 8; // Number of seconds to display to the right of current time
            oneSecondPx = widthToRightOfCurrent / numSecondsToRightOfCurrent; // One second in pixels
            double durationPx = _duration * oneSecondPx; // Total duration in pixels
            double currentTimePx = currentTime * oneSecondPx; // Current time in pixels

            double currentLinePx = widthToLeftOfCurrent; // Distance of current line from left of screen
            double bottomLinePx = 0.11 * availableWidth; // Distance of bottom line from left of screen
            double chromaBlockerPx = availableWidth - bottomLinePx; // Distance of chroma blocker from right of screen

            double deltaHeightPx = availableHeight / (2 + cnst.numPitches - 1 + 2); // Vertical offset for horizontal lines
            double deltaWidthPx = currentLinePx - bottomLinePx; // Horizontal offset between current line and bottom line

            double pitchLabelPx = (availableWidth - currentLinePx); // Distance of pitch labels from right of the screen
            double playButtonPx = 0.06 * availableWidth; // Distance of play button from right of screen

            // Chromagram pitch intensity bars
            for (int i = 0; i < cnst.numPitches; i++) {
              double height = deltaHeightPx / 2;
              Widget pitchIntensityBar = Positioned(
                bottom: (i + 2) * deltaHeightPx - height / 2,
                left: currentLinePx, 
                child: Transform.translate(
                  offset: Offset(-currentTimePx, 0),  // Translate horizontally based on current playback time
                  child: ib.IntensityBar(
                    values: widget.chromagram[(i + _tonicIndex) % cnst.numPitches],
                    orientation: 'horizontal',
                    height: height, 
                    width: durationPx,
                  ),
                ),
              );
              allWidgets.add(pitchIntensityBar);
            }

            for (int i = 0; i < cnst.numPitches; i++) {
              Widget horizontalPitchLine = Positioned(
                left: currentLinePx,
                top: (i + 2) * deltaHeightPx,
                child: Transform.translate(
                  offset: Offset(-currentTimePx, 0), // Move left as currentTime increases
                  child: Container(
                    height: 1,
                    width: durationPx,
                    color: Colors.grey,
                  ),
                ),
              );
              allWidgets.add(horizontalPitchLine);
            }

            // Blocker to cover chroma bars below pitch line
            Widget chromaBlocker = Positioned(
              top: 0,
              bottom: 0,
              right: chromaBlockerPx,
              left: 0,
              child: Container(
                color: Colors.black,
              ),
            );
            allWidgets.add(chromaBlocker);

            const double pitchLabelHeight = 20; // Approximate height for label centering
            for (int i = 0; i < cnst.numPitches; i++) {
              // Center the label at the same height as the horizontalPitchLine
              // Determine if pitch is in scale
              final scalePattern = cnst.scalePatterns[_scale];
              final isInScale = scalePattern != null && scalePattern[i] == 1;
              Widget pitchLabel = Positioned(
                bottom: (i + 2) * deltaHeightPx - pitchLabelHeight / 2,
                right: pitchLabelPx,
                child: Transform.translate(
                  offset: Offset(- min(currentTimePx, deltaWidthPx), 0),
                  child: SizedBox(
                    width: 24,
                    height: pitchLabelHeight,
                    child: Center(
                      child: Text(
                        AppSettings.instance.showPitchClasses ? cnst.pitchClassNames[(i + _tonicIndex) % cnst.numPitches] : cnst.scaleDegrees[i],
                        style: TextStyle(
                          color: isInScale ? Colors.white : Colors.grey,
                          fontSize: 12,
                          fontWeight: isInScale ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              );
              allWidgets.add(pitchLabel);
            }

            // Estimated key text below the start line
            double fadeOutTime = (deltaWidthPx / oneSecondPx); // Time in seconds over which text fades out
            double keyTextOpacity = (1 - (currentTime / fadeOutTime)).clamp(0.0, 1.0);
            const double keyTextHeight = 24; // Approximate height for key text
            Widget keyText = Positioned(
              right: availableWidth - currentLinePx + 10,
              bottom: deltaHeightPx - keyTextHeight / 2,
              child: Transform.translate(
                offset: Offset(-min(currentTimePx, deltaWidthPx), 0),
                child: Opacity(
                  opacity: keyTextOpacity,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Key: ',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.normal),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => _editMusicalKey(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey[850],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _musicalKey,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ),
              ),
            );
            allWidgets.add(keyText);

            // Start vertical line
            Widget startLine = Positioned(
              top: 2*deltaHeightPx,
              bottom: 2*deltaHeightPx,
              left: currentLinePx,
              child: Transform.translate(
                offset: Offset(-min(currentTimePx, deltaWidthPx), 0), 
                child: Container(
                  width: 1,
                  color: Colors.grey,
                ),
              ),
            );
            allWidgets.add(startLine);

            // End vertical line
            Widget endLine = Positioned(
              top: 2*deltaHeightPx,
              bottom: 2*deltaHeightPx,
              left: currentLinePx + durationPx,
              child: Transform.translate(
                offset: Offset(-currentTimePx, 0), 
                child: Container(
                  width: 1,
                  color: Colors.grey,
                ),
              ),
            );
            allWidgets.add(endLine);

            // Current position of audio playback
            Widget currentLine = Positioned(
              left: currentLinePx,
              top: deltaHeightPx,
              bottom: deltaHeightPx,
              child: Container(
                width: 1,
                color: Colors.white,
              ),
            );
            allWidgets.add(currentLine);

             // Right arrow icon at current position
            double iconSize = 30;
            Widget downArrow = Positioned(
              top: deltaHeightPx - iconSize / 2, 
              left: currentLinePx - iconSize / 2 + 0.5,
              child: Transform.rotate(
                angle: pi / 2, // 90 degrees clockwise
                child: Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: iconSize,
                ),
              ),
            );
            allWidgets.add(downArrow);

            // Play button at height 2 * deltaHeightPx from bottom right
            double playButtonRadius = 30;
            double playButtonIconSize = 38;
            Widget playButton = Positioned(
              right: playButtonPx,
              // Place the center of the button at 2 * deltaHeightPx from the bottom
              bottom: (2 * deltaHeightPx) - playButtonRadius,
              child: _playButton(radius: playButtonRadius, iconSize: playButtonIconSize),
            );
            allWidgets.add(playButton);
          }
          
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragStart: isPortrait
                ? (_) {
                    if (isFlinging) {
                      _abortFling();
                      return;
                    }
                    if (isPlaying) {
                      _resumePlayingLater = true;
                      pause();
                      return;
                    }
                    _resumePlayingLater = false;
                  }
                : null,
            onVerticalDragUpdate: isPortrait
                ? (details) {
                    if (!mounted) return;
                    setState(() {
                      currentTime += details.primaryDelta! / oneSecondPx;
                      currentTime = currentTime.clamp(0.0, _duration);
                    });
                  }
                : null,
            onVerticalDragEnd: isPortrait
                ? (details) {
                    double flingVelocity = (details.primaryVelocity ?? 0.0) / oneSecondPx;
                    _startFling(flingVelocity);
                  }
                : null,
            onHorizontalDragStart: !isPortrait
                ? (_) {
                    if (isFlinging) {
                      _abortFling();
                      return;
                    }
                    if (isPlaying) {
                      _resumePlayingLater = true;
                      pause();
                      return;
                    }
                    _resumePlayingLater = false;
                  }
                : null,
            onHorizontalDragUpdate: !isPortrait
                ? (details) {
                    if (!mounted) return;
                    setState(() {
                      currentTime -= details.primaryDelta! / oneSecondPx;
                      currentTime = currentTime.clamp(0.0, _duration);
                    });
                  }
                : null,
            onHorizontalDragEnd: !isPortrait
                ? (details) {
                    double flingVelocity = -(details.primaryVelocity ?? 0.0) / oneSecondPx;
                    _startFling(flingVelocity);
                  }
                : null,
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
  Widget _playButton({double radius = 30, double iconSize = 38}) {
    Color iconColor = Colors.black;
    Color backgroundColor = Colors.white;

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
          conv.formatTime(currentTime),
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
        Text(
          conv.formatTime(_duration),
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
}









