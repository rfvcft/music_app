import 'dart:io'; // For platform checks 
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:just_audio/just_audio.dart' as ja; // Audio player package

import 'package:music_app/core/app_settings.dart'; // App settings
import 'package:music_app/screens/settings.dart'; // Settings page
import 'package:music_app/utils/chromagram_builder.dart' as cb; // Chromagram builder for visualization
import 'package:music_app/utils/conversion.dart' as conv; // Conversion utilities
import 'package:music_app/utils/constants.dart' as cnst; // Import constants

const bool showLogs = true; // Set to true to enable logs for debugging

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
        numFrames = chromagram.isNotEmpty ? chromagram[0].length : 0 {
    if (chromagram.isEmpty) {
      throw ArgumentError('Chromagram must not be empty.');
    }
    if (numBins != 72) {
      throw ArgumentError('Chromagram must have 72 bins, got $numBins.');
    }
  }
  

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

  double? leftShift; // Track horizontal shift from horizontal scroll gestures (0.0 = no shift, 1.0 = maximum shift)
  late double _initialLeftShift; // Auxilliary variable used for starting fling ticker

  late double _flingVelocity; // Velocity of fling in seconds per second
  late Ticker _flingTicker; // Ticker for fling animation
  bool _resumePlayingLater = false; // Track if playback should resume after scrolling
  late bool _isVerticalFling; // Track if fling is vertical (for controlling playback) or horizontal (for controlling leftShift)
  bool isFlinging = false; // Track whether a fling animation is in progress

  late Ticker _timeTicker; // Ticker for updating currentTime while audio playback

  final ja.AudioPlayer _player = ja.AudioPlayer(); // Audio player for playback
  double _duration = 0.0; // Duration of audio file in seconds
  bool isPlaying = false; // Track whether audio/visuals are playing

  bool get isComplete => (currentTime >= _duration); // Track whether audio has completed playing

  String _musicalKey = ''; // Musical key of the audio (may be edited by user)
  int _tonicIndex = -1; // Tonic index of the audio
  String _scale = ''; // Scale of the audio 

  cb.ChromagramBuilder? _chromagramBuilder; // Chromagram builder for building chromagram visualization based on current parameters

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
      if (duration != null) {
        double newDuration = duration.inMilliseconds / 1000.0;
        if (newDuration == _duration) return;
        if (!mounted) return;
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
    if (elapsedTime > minTimeForAudioSync && deltaToAudio > maxDeltaToAudio) {
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
  void _startFling(double flingVelocity, bool isVertical) {
    _flingVelocity = flingVelocity; // Set fling velocity
    _isVerticalFling = isVertical; // Set fling direction
    if (isVertical) {
      _initialTime = currentTime; // Fix initial time for vertical fling ticker updates
    } else {
      _initialLeftShift = leftShift!; // Fix initial leftShift for horizontal fling ticker updates
    }
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
    if (_resumePlayingLater) {
      play();
      _resumePlayingLater = false;
    }
  }

  // Update current time based on fling velocity. To be called by fling ticker
  void _flingUpdate(Duration elapsed) {
    if (!isFlinging) return;

    // Exponential decay model for fling
    double dampingFactor = _isVerticalFling ? 4.0 : 6.0;
    double delta = (_flingVelocity / dampingFactor) * (1 - exp(-dampingFactor * elapsed.inMilliseconds / 1000.0));
    double deltaLimit = (_flingVelocity / dampingFactor); 
    double diff = (deltaLimit - delta).abs();

    if (!mounted) return;
      if (_isVerticalFling) {
      setState(() {
        // Update currentTime based on fling velocity and elapsed time
        currentTime = _initialTime + delta; 
        
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
        if (diff < 0.1) {
          _endFling();
          return;
        } 
      });
      if (showLogs) print('setState: _flingUpdate()');
      return;
    }

    setState(() {
      // Update leftShift based on fling velocity and elapsed time
      leftShift = _initialLeftShift + delta;

      if (leftShift! < 0.0) {
        leftShift = 0.0;
        _endFling();
        return;
      }
      if (leftShift! > 1.0) {
        leftShift = 1.0;
        _endFling();
        return;
      }
      if (diff < 0.1) {
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
        leftShift = null; 
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
          // Initialize chromagram builder (if not already initialized)
          _chromagramBuilder ??= cb.ChromagramBuilder(
            duration: _duration,
            chromagram: widget.chromagram,
            onEditMusicalKey: () => _editMusicalKey(context),
            onSliderChanged: (value) {
              setState(() {
                currentTime = value;
              });
            },
            onSliderChangeStart: (value) {
              if (isFlinging) _abortFling();
              if (isPlaying) {
                _resumePlayingLater = true;
                pause();
              }
            },
            onSliderChangeEnd: (value) {
              if (_resumePlayingLater) {
                play();
              }
            },
            onPlayButtonPressed: () {
              if (isFlinging) _abortFling();
              if (isPlaying) {
                pause();
              } else {
                play();
              }
            },
            onPlayButtonReset: () {
              reset();
            },
          );

          final availableWidthPx = constraints.maxWidth; 
          final availableHeightPx = constraints.maxHeight; 
          final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;

          // Build visuals based on current parameters using chromagram builder
          List<Widget> chromagramWidgets = _chromagramBuilder!.buildChromagram(
            context: context,
            availableWidthPx: availableWidthPx,
            availableHeightPx: availableHeightPx,
            currentTime: currentTime,
            leftShift: leftShift,
            isPortrait: isPortrait,
            isPlaying: isPlaying,
            isComplete: isComplete,
            musicalKey: _musicalKey,
            tonicIndex: _tonicIndex,
            scale: _scale,
          );

          leftShift = _chromagramBuilder!.getLeftShift(); //leftShift might be changed by chromagram builder at initialization or when musical key is edited

          double oneSecondPx = _chromagramBuilder!.getOneSecondPx(); // Get pixel equivalent of one second for converting drag distances to time changes
          double leftShiftToPx = _chromagramBuilder!.getLeftShiftToPx(); // Get pixel equivalent of maximum left shift for converting drag distances to leftShift changes
          
          // Main gesture handler for scrubbing and flinging through the audio timeline.
          // Handles vertical drags in portrait and horizontal drags in landscape.
          return GestureDetector(
            behavior: HitTestBehavior.opaque, // Ensures gestures are detected anywhere in the area

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
              bool isVertical = true;
              _startFling(flingVelocity, isVertical);
            },

            onHorizontalDragStart: (_) {
              if (isFlinging) {
                _abortFling();
                return;
              }
            },
            onHorizontalDragUpdate: (details) {
              // Update leftShift based on horizontal drag
              if (leftShift == null) return; // If leftShift is not initialized, ignore drag updates
              if (!mounted) return;
              setState(() {
                leftShift = leftShift! - details.primaryDelta! / leftShiftToPx; 
                leftShift = leftShift!.clamp(0.0, 1.0);
              });
              if (showLogs) print('setState: onHorizontalDragUpdate, leftShift: $leftShift');
            },
            onHorizontalDragEnd: (details) {
              // Start fling animation based on horizontal drag velocity
              double flingVelocity = -(details.primaryVelocity ?? 0.0) / leftShiftToPx; // Convert pixels/sec to leftShift/sec
              bool isVertical = false;
              _startFling(flingVelocity, isVertical);
            },

            // The main visual stack (timeline, bars, labels, etc.)
            child: SizedBox.expand(
              child: Stack(
                children: chromagramWidgets,
              ),
            ),
          );
        },
      ),
    );
  }
}









