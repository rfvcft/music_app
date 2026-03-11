import 'dart:io'; // For platform checks 
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:just_audio/just_audio.dart' as ja; // Audio player package

import 'package:music_app/core/app_settings.dart'; // App settings
import 'package:music_app/screens/settings.dart'; // Settings page
import 'package:music_app/utils/intensity_bar.dart' as ib; // Intensity bar widget
import 'package:music_app/utils/conversion.dart' as conv; // Conversion utilities
import 'package:music_app/utils/constants.dart' as cnst; // Import constants

const bool showLogs = false; // Set to true to enable logs for debugging

// Screen for visualizing the chromagram of an audio file. Users can control playback via scroll, fling gestures or a slider. 
class Visualizer extends StatefulWidget {
  Visualizer({
    super.key,
    required this.audioName,
    required this.audioUrl,
    required this.duration,
    required this.musicalKey,
    required this.chromagram,
  }) :
      numBins = chromagram.length,
      numFrames = chromagram[0].length;
  

  final String audioName; // Name of the audio file (without extension)
  final String audioUrl; // URL or asset path to audio file
  final double duration; // Duration of audio in seconds (computed by C++ library)
  final String musicalKey; // Musical key of the audio
  final List<List<double>> chromagram; // Chromagram (midi bins x time frames)

  final int numBins;
  final int numFrames; // Number of time frames (proportional to duration)

  @override
  State<Visualizer> createState() => _VisualizerState();
}

class _VisualizerState extends State<Visualizer> with SingleTickerProviderStateMixin {
  
  double currentTime = 0.0; // Current time in seconds. Visuals are based on this variable.

  late double _initialTime; // Auxilliary variable used for starting tickers

  late double _flingVelocity; // Velocity of fling in seconds per second
  late Ticker _flingTicker; // Ticker for fling animation
  late bool _resumePlayingLater; // Track if playback should resume after scrolling
  bool isFlinging = false; // Track whether a fling animation is in progress

  late Ticker _timeTicker; // Ticker for updating currentTime while audio playback

  final ja.AudioPlayer _player = ja.AudioPlayer(); // Audio player for playback
  double _duration = 0.0; // Duration of audio file in seconds
  bool isPlaying = false; // Track whether audio/visuals are playing

  bool get isComplete => (currentTime >= _duration); // Track whether audio has completed playing

  double leftShift = 0.0; // Track horizontal shift from horizontal scroll gestures (0.0 = no shift, 1.0 = maximum shift)

  String _musicalKey = ''; // Musical key of the audio (may be edited by user)
  int _tonicIndex = -1; // Tonic index of the audio
  String _scale = ''; // Scale of the audio 

  // Initialize states
  @override
  void initState() {
    super.initState();
    if (showLogs) print('INITIALIZING VISUALIZER FOR ${widget.audioName}');

    // Initialize musical key
    _musicalKey = widget.musicalKey;
    var parsed = conv.parseMusicalKey(_musicalKey);
    _tonicIndex = parsed.$1;
    _scale = parsed.$2;

    // Initialize fling ticker for updating currentTime during fling animations
    _flingTicker = Ticker(_flingUpdate);

    // Initialize time ticker for updating currentTime during playback
    _timeTicker = Ticker(_timeUpdate);

    // Use AudioSource.asset for asset paths, AudioSource.uri otherwise
    if (widget.audioUrl.startsWith('assets/')) {
      _player.setAudioSource(ja.AudioSource.asset(widget.audioUrl));
    } else {
      _player.setAudioSource(ja.AudioSource.uri(Uri.parse(widget.audioUrl)));
    }

    // Get duration from audio player stream (should be fixed since we are reading an audio file)
    _player.durationStream.listen((duration) {
      if (!mounted) return;
      if (duration != null) {
        double newDuration = duration.inMilliseconds / 1000.0;
        if (newDuration == _duration) return;
        setState(() {
          _duration = newDuration;
        });
        if (showLogs) print('setState: durationStream listener');
        if (showLogs) print('AUDIO DURATION COMPUTED BY just_audio: $_duration seconds');
        if (showLogs) print('AUDIO DURATION COMPUTED BY C++ LIBRARY: ${widget.duration} seconds');
      }
    });
  }

  // Clean up resources
  @override
  void dispose() {   
    _flingTicker.dispose();
    _timeTicker.dispose();
    _player.dispose();
    super.dispose();
  }

  // Play audio and start visualization
  Future<void> play() async {
    _initialTime = currentTime;

    // Hacky workaround to enforce correct position stream (happens on Bluetooth on iOS. Audioplayer needs to play for a little and then, after a restart, position stream is correct and in sync with actual audio playback)
    await _player.seek(Duration(milliseconds: (_initialTime * 1000).toInt()));
    _player.setVolume(0.0);
    _player.play();
    await Future.delayed(const Duration(milliseconds: 50));
    _player.pause();
    _player.setVolume(1.0);

    // Seek audioplayer to _initialTime
    await _player.seek(Duration(milliseconds: (_initialTime * 1000).toInt()));
    //await _player.load();
    if (showLogs) print('AUDIO PLAYER SEEKED TO: $_initialTime seconds.');

    // Start audio playback and time ticker (hopefully simultaneously)
    _player.play();
    _timeTicker.start();
    
    if (showLogs) print('AUDIO PLAYBACK STARTED AT: $_initialTime seconds');

    // Redraw UI 
    if (!mounted) return;
    setState(() {
      isPlaying = true;
    });
    if (showLogs) print('setState: play()');
  }

  // Pause audio and visualization
  void pause() {
    // Pause audio playback (this stops currentTime updates from position stream)
    _player.pause();
    _timeTicker.stop(); // Stop time ticker to stop updating currentTime
    if (showLogs) print('AUDIO PLAYBACK PAUSED AT: $currentTime seconds');

    // Redraw UI
    if (!mounted) return;
    setState(() {
      isPlaying = false;
    });
    if (showLogs) print('setState: pause()');
  }

  // Resets audio and visuals to the start 
  void reset() {
    if (showLogs) print('RESETTING PLAYBACK');
    // Reset audio playback
    _player.pause();
    _player.seek(Duration.zero);
    _timeTicker.stop(); // Stop time ticker to stop updating currentTime

    // Redraw UI with reset currentTime
    if (!mounted) return;
    setState(() {
      isPlaying = false;
      currentTime = 0.0;
    });
    if (showLogs) print('setState: reset()');
    if (showLogs) print('CURRENT TIME AFTER RESET: $currentTime seconds');
  }

  // Update time based on time ticker. The ticker is started in play() and paused in pause(). If the time ticker is out of sync with the audio player position, it is resynced. Also guards against non-monotone increasing time values. 
  void _timeUpdate(Duration elapsed) {
    double elapsedTime = elapsed.inMilliseconds / 1000.0; // Elapsed time since play() was called (or ticker was restarted for resyncing with audio player position)
    double newTime = _initialTime + elapsedTime;
    double playerPosition = _player.position.inMilliseconds / 1000.0;
    const minTimeForAudioSync = 0.5; // Minimum time before trusting audio player position for sync (to allow for audio player to buffer and start playback)
    double deltaToAudio = (newTime - playerPosition).abs();
    const double maxDeltaToAudio = 0.010; // Maximum tolerated difference to audio player position

    // Check if audio has completed playing
    if (newTime > _duration) {
      currentTime = _duration; 
      pause();
      return;
    }

    // Guard against out of sync UI 
    if (newTime > minTimeForAudioSync && deltaToAudio > maxDeltaToAudio) {
      _timeTicker.stop();
      _initialTime = playerPosition; // Resync with audio player position
      _timeTicker.start();
      if (showLogs) print('WARNING: currentTime OUT OF SYNC WITH AUDIO PLAYER POSITION BY $deltaToAudio seconds. RESYNCING TIME TICKER WITH AUDIO PLAYER POSITION AT $playerPosition seconds.');
      return;
    }

    // Safeguard against non-monotone increasing newTime values (might happen when audio player position stream jumped back and hence ticker was resynced to an earlier time)
    if (newTime < currentTime) {
      if (showLogs) print('WARNING: newTime ($newTime seconds) IS LESS THAN currentTime ($currentTime seconds). SKIPPING TIME UPDATE.');
      return; 
    }
    
    // Redraw UI
    setState(() {
      if (showLogs) print('TIME UPDATED WITH DELTA: ${newTime - currentTime} seconds');
      currentTime = newTime;
    });
    if (showLogs) print('setState: _timeUpdate()');
    if (showLogs) print('CURRENT TIME UPDATED FROM _timeUpdate: $currentTime seconds. AUDIO PLAYER POSITION: ${_player.position.inMilliseconds / 1000.0} seconds');
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
    if (showLogs) print('setState: _flingUpdate()');
  }

  // Show dialog to edit musical key
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

    // Shift pitchClassNames so that A is first
    final shiftedPitchClassNames = [
      ...cnst.pitchClassNames.sublist(9),
      ...cnst.pitchClassNames.sublist(0, 9)
    ];

    // Let the user select new key via dialog
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
                      items: shiftedPitchClassNames.map((tonic) {
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
      if (showLogs) print('setState: _editMusicalKey dialog result');
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
              // Abort fling and pause playback before navigating to settings
              if (isFlinging) _abortFling();
              if (isPlaying) pause();
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => SettingsPage()),
              );
              // After returning, call setState to rebuild with new settings
              setState(() {});
              if (showLogs) print('setState: after returning from SettingsPage');
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth; 
          final availableHeight = constraints.maxHeight; 

          List<Widget> allWidgets = [];

          final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;

          int numberOfNotesInScale = 0; // Count how many notes in range [0, numBins) are in scale
          if (isPortrait) {
            for (int i = 0; i < widget.numBins; i++) {
              final scalePattern = cnst.scalePatterns[_scale];
              final isInScale = scalePattern != null && scalePattern[(i - _tonicIndex) % cnst.numPitches] == 1;
              if (isInScale) numberOfNotesInScale++;
            }
          } 

          int numSecondsAboveCurrent = isPortrait ? 5 : 4; // Number of seconds to display above current time
          double heightAboveCurrent = isPortrait ? cnst.goldenFactorLarge * availableHeight : 0.75 * availableHeight; // Available height above current line
          double heightBelowCurrent = isPortrait ? cnst.goldenFactorSmall * availableHeight : 0.25 * availableHeight; // Available height below current line

          double oneSecondPx = heightAboveCurrent / numSecondsAboveCurrent; // One second in pixels
          double durationPx = _duration * oneSecondPx; // Total duration in pixels
          double currentTimePx = currentTime * oneSecondPx; // Current time in pixels

          double currentLinePx = heightBelowCurrent; // Distance of current line from bottom of screen
          double sliderLinePx = isPortrait ? cnst.goldenFactorLarge * heightBelowCurrent : 0.0; // Distance of slider line from bottom of screen (not used in landscape mode)

          int numberOfNotesToDisplay = isPortrait ? 12 : 32; // How many notes to display
          double deltaWidthPx = availableWidth / (2 + numberOfNotesToDisplay - 1 + 2); // Horizontal offset for vertical lines 
          double deltaHeightPx = isPortrait ? cnst.goldenFactorLarge * (currentLinePx - sliderLinePx) : 0.6 * heightBelowCurrent; // Vertical offset between current line and bottom line 

          double bottomLinePx = currentLinePx - deltaHeightPx; // Distance of bottom line from bottom of screen 
          double chromaBlockerPx = availableHeight - bottomLinePx; // Height of chroma blocker from top of screen

          double playButtonPx = isPortrait ? (availableHeight - sliderLinePx) + 0.15 *sliderLinePx : 0.0; // Distance of top of audio player to top of screen
          double timeDisplayPx = isPortrait ? (availableHeight - sliderLinePx) + 0.05 * sliderLinePx : 0.0; // Distance of top of time display to top of screen (not used in landscape mode)

          double pitchLabelPx = (availableHeight - currentLinePx); // Distance of top of pitch labels from bottom of screen
          double keyTextPx = isPortrait ? (availableHeight - currentLinePx) + 0.075 * currentLinePx : (availableHeight - currentLinePx) + 0.3 * currentLinePx; // Distance of key text from top of screen

          double leftShiftToPx =  ((isPortrait ? numberOfNotesInScale : widget.numBins) - numberOfNotesToDisplay) * deltaWidthPx; // Maximum horizontal shift in pixels (when leftShift = 1.0)
          double leftShiftPx = leftShift * leftShiftToPx; // Horizontal shift to the left (based on leftShift value from horizontal scroll gestures)

          // Chromagram pitch intensity bars
          double safetyMarginPx = 0.5 * oneSecondPx; // Safety margin in pixels (we draw a few extra pixels above and below visual window)
          double heightAboveCurrentSeconds = heightAboveCurrent / oneSecondPx; // Height above current line in seconds
          double deltaHeightSeconds = deltaHeightPx / oneSecondPx; 
          double safetyMarginSeconds = safetyMarginPx / oneSecondPx; 
          int safetyMarginFrames = (safetyMarginSeconds / (_duration / widget.numFrames)).ceil(); // Safety margin in frames
          int startIndex = max(0, ((currentTime - deltaHeightSeconds) / _duration * widget.numFrames).ceil() - safetyMarginFrames); // Index of first frame to display, with safety margin
          int endIndex = min(widget.numFrames, ((currentTime + heightAboveCurrentSeconds) / _duration * widget.numFrames).floor() + safetyMarginFrames); // Index of last frame to display, with safety margin
          int currentNumberOfPitchBars = 0;
          double pitchBarWidthPx = 0.5 * deltaWidthPx; // Width of each pitch intensity bar in pixels
          for (int i = 0; i < widget.numBins; i++) {
            final scalePattern = cnst.scalePatterns[_scale];
            final isInScale = scalePattern != null && scalePattern[(i - _tonicIndex) % cnst.numPitches] == 1; // Determine if pitch class is in scale
            if (isPortrait && !isInScale) continue; // In portrait mode, only show pitch classes in the scale to reduce clutter
            currentNumberOfPitchBars++;
            double centerOfPitchBarPx = (currentNumberOfPitchBars + 1) * deltaWidthPx - leftShiftPx; // Center of pitch bar in pixels
            if (centerOfPitchBarPx < 0 || centerOfPitchBarPx > availableWidth) {
              continue; // Skip drawing pitch bars that are completely outside of the visual window
            }
            double opacityOfPitchBar = 1.0; // Fade out pitch bar at boundary 
            if (centerOfPitchBarPx < 2 * deltaWidthPx) {
              opacityOfPitchBar = ((centerOfPitchBarPx - deltaWidthPx) / deltaWidthPx).clamp(0.0, 1.0);
            } else if (centerOfPitchBarPx > (availableWidth - 2 * deltaWidthPx)) {
              opacityOfPitchBar = ((availableWidth - deltaWidthPx - centerOfPitchBarPx) / deltaWidthPx).clamp(0.0, 1.0);
            }
            Widget pitchIntensityBar = Positioned(
              left: centerOfPitchBarPx - pitchBarWidthPx / 2,
              bottom: currentLinePx, 
              child: Transform.translate(
                offset: Offset(0, currentTimePx),  // Translate vertically down based on current playback time
                child: Opacity(
                  opacity: opacityOfPitchBar,
                  child: ib.IntensityBar(
                    values: widget.chromagram[i],
                    orientation: 'vertical',
                    width: pitchBarWidthPx, 
                    height: durationPx,
                    startIndex: startIndex,
                    endIndex: endIndex,
                    enhancedResolution: Platform.isIOS ? true : false, // Enhanced resolution on iOS only
                  ),
                ),
              ),
            );
            allWidgets.add(pitchIntensityBar);
          }

          // Vertical lines for pitch classes
          double topOfVerticalPitchLinePx = (availableHeight - currentLinePx) - (durationPx - currentTimePx);
          int currentNumberOfNotes = 0;
          for (int i = 0; i < widget.numBins; i++) {
            final scalePattern = cnst.scalePatterns[_scale];
            final isInScale = scalePattern != null && scalePattern[(i - _tonicIndex) % cnst.numPitches] == 1; // Determine if pitch class is in scale
            if (isPortrait && !isInScale) continue; // In portrait mode, only show pitch classes in the scale to reduce clutter
            currentNumberOfNotes++;

            double centerOfVerticalPitchLinePx = (currentNumberOfNotes + 1) * deltaWidthPx - leftShiftPx;
            if (centerOfVerticalPitchLinePx < deltaWidthPx || centerOfVerticalPitchLinePx > (availableWidth - deltaWidthPx)) {
              continue; // Skip drawing vertical lines that are completely outside of the visual window
            }
            double opacityOfVerticalPitchLine = 1.0;

            if (centerOfVerticalPitchLinePx < 2 * deltaWidthPx) {
              opacityOfVerticalPitchLine = ((centerOfVerticalPitchLinePx - deltaWidthPx) / deltaWidthPx).clamp(0.0, 1.0);
            } else if (centerOfVerticalPitchLinePx > (availableWidth - 2 * deltaWidthPx)) {
              opacityOfVerticalPitchLine = ((availableWidth - deltaWidthPx - centerOfVerticalPitchLinePx) / deltaWidthPx).clamp(0.0, 1.0);
            }
            Widget verticalPitchLine = Positioned(
              left: centerOfVerticalPitchLinePx,
              width: 1,
              bottom: currentLinePx - min(currentTimePx, deltaHeightPx), 
              top: max(topOfVerticalPitchLinePx, 0),
              child: Opacity(
                opacity: opacityOfVerticalPitchLine,
                child: Container(
                  width: 1,
                  color: isInScale ? Colors.grey[400]! : Colors.grey[900]!, // Lighter vertical line for pitch classes in the scale, darker for those not in the scale
                ),
              ),
            );
            allWidgets.add(verticalPitchLine);
          }

          // Start horizontal line
          double startLineLeftPx = 2*deltaWidthPx - leftShiftPx;
          double startLineRightPx = availableWidth - (2 * deltaWidthPx - leftShiftPx + ((isPortrait ? numberOfNotesInScale : widget.numBins) - 1) * deltaWidthPx);
          Widget startLine = Positioned(
            left: max(startLineLeftPx, deltaWidthPx),
            right: max(startLineRightPx, deltaWidthPx),
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
          double endLineLeftPx = 2*deltaWidthPx - leftShiftPx;
          double endLineRightPx = availableWidth - (2 * deltaWidthPx - leftShiftPx + (widget.numBins - 1) * deltaWidthPx);
          Widget endLine = Positioned(
            left: max(endLineLeftPx, deltaWidthPx),
            right: max(endLineRightPx, deltaWidthPx) - 1,
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

          // Pitch class labels
          int currentNumberOfPitchLabels = 0;
          for (int i = 0; i < widget.numBins; i++) {
            // Add pitch class label below startLine, translated with currentTimePx
            // Determine if pitch is in scale
            final scalePattern = cnst.scalePatterns[_scale];
            final isInScale = scalePattern != null && scalePattern[(i - _tonicIndex) % cnst.numPitches] == 1;
            if (isPortrait && !isInScale) continue; // In portrait mode, only show pitch classes in the scale to reduce clutter
            currentNumberOfPitchLabels++;
            double centerOfPitchLabelPx = (currentNumberOfPitchLabels + 1) * deltaWidthPx - leftShiftPx;
            if (centerOfPitchLabelPx < deltaWidthPx || centerOfPitchLabelPx > (availableWidth - deltaWidthPx)) {
              continue; // Skip drawing pitch labels that are completely outside of the visual window
            }
            double opacityOfPitchLabel = 1.0;
            if (centerOfPitchLabelPx < 2 * deltaWidthPx) {
              opacityOfPitchLabel = ((centerOfPitchLabelPx - deltaWidthPx) / deltaWidthPx).clamp(0.0, 1.0);
            } else if (centerOfPitchLabelPx > (availableWidth - 2 * deltaWidthPx)) {
              opacityOfPitchLabel = ((availableWidth - deltaWidthPx - centerOfPitchLabelPx) / deltaWidthPx).clamp(0.0, 1.0);
            }
            Widget pitchLabel = Positioned(
              left: centerOfPitchLabelPx - 16, // Center label under line
              top: pitchLabelPx,
              child: Transform.translate(
                offset: Offset(0, min(currentTimePx, deltaHeightPx)),
                child: SizedBox(
                  width: 32,
                  child: Center(
                    child: Text(
                      cnst.absoluteNoteNames[i],
                      style: TextStyle(
                          color: isInScale ? Colors.white.withValues(alpha: opacityOfPitchLabel) : Colors.grey[600]!.withValues(alpha: opacityOfPitchLabel),
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
            left: deltaWidthPx - iconSize / 2,
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
            right: 0,
            left: isPortrait ? 0 : null, // In portrait mode, center the play button. In landscape mode, align it to the right.
            top: playButtonPx, 
            child: Center(child: _playButton(radius: playButtonRadius, iconSize: playButtonIconSize)),
          );
          allWidgets.add(playButton);

          // Slider with time display 
          if (isPortrait) { // only in portrait mode to avoid cluttering landscape mode
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
          }
          
          // Main gesture handler for scrubbing and flinging through the audio timeline.
          // Handles vertical drags in portrait and horizontal drags in landscape.
          return GestureDetector(
            behavior: HitTestBehavior.opaque, // Ensures gestures are detected anywhere in the area

            // --- Portrait mode: vertical drag to scrub/fling ---
            onVerticalDragStart: (_) {
              // Abort any ongoing fling if user starts a new drag
              if (isFlinging) {
                _abortFling();
                return;
              }
              // Pause playback if currently playing, and remember to resume after drag
              if (isPlaying) {
                _resumePlayingLater = true;
                pause();
                return;
              }
              _resumePlayingLater = false;
            },
            onVerticalDragUpdate: (details) {
              // Move currentTime based on drag distance (pixels to seconds)
              if (!mounted) return;
              setState(() {
                currentTime += details.primaryDelta! / oneSecondPx;
                currentTime = currentTime.clamp(0.0, _duration);
              });
              if (showLogs) print('setState: onVerticalDragUpdate');
            },
            onVerticalDragEnd: (details) {
              // Start a fling animation based on drag velocity
              double flingVelocity = (details.primaryVelocity ?? 0.0) / oneSecondPx; // Convert pixels/sec to seconds/sec
              _startFling(flingVelocity);
            },

            // --- Landscape mode: horizontal drag to scrub/fling ---
            onHorizontalDragStart: null,
            onHorizontalDragUpdate: (details) {
              // Update leftShift based on horizontal drag
              if (!mounted) return;
              setState(() {
                leftShift -= details.primaryDelta! / leftShiftToPx; // Adjust divisor for sensitivity
                leftShift = leftShift.clamp(0.0, 1.0);
              });
              if (showLogs) print('setState: onHorizontalDragUpdate, leftShift: $leftShift');
            },
            onHorizontalDragEnd: (details) {
              // Start fling animation based on horizontal drag velocity
              double flingVelocity = (details.primaryVelocity ?? 0.0) / leftShiftToPx; // Convert pixels/sec to leftShift/sec
              //_startFling(flingVelocity);
            },

            // The main visual stack (timeline, bars, labels, etc.)
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
          if (showLogs) print('setState: _playbackSlider onChanged');
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









