import 'dart:async';

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// AudioPlayer widget for playing audio files with playback controls
class AudioPlayer extends StatefulWidget {
  /// Path from where to play recorded audio
  final String source;

  /// Callback when audio file should be removed
  /// Setting this to null hides the delete button
  final VoidCallback onDelete;

  const AudioPlayer({
    super.key,
    required this.source,
    required this.onDelete,
  });

  @override
  AudioPlayerState createState() => AudioPlayerState();
}

/// State class for AudioPlayer
class AudioPlayerState extends State<AudioPlayer> {
  static const double _controlSize = 56;
  static const double _deleteBtnSize = 24;

  // The audio player instance from audioplayers package
  final _audioPlayer = ap.AudioPlayer()..setReleaseMode(ReleaseMode.stop);

  // Subscriptions to listen for player state, duration, and position changes
  late StreamSubscription<void> _playerStateChangedSubscription;
  late StreamSubscription<Duration?> _durationChangedSubscription;
  late StreamSubscription<Duration> _positionChangedSubscription;

  // Current playback position and total duration
  Duration? _position;
  Duration? _duration;

  @override
  void initState() {
    // Listen for playback completion to reset player
    _playerStateChangedSubscription = _audioPlayer.onPlayerComplete.listen((state) async {
      await stop();
    });
    // Listen for position changes to update UI
    _positionChangedSubscription = _audioPlayer.onPositionChanged.listen(
      (position) => setState(() {
        _position = position;
      }),
    );
    // Listen for duration changes to update UI
    _durationChangedSubscription = _audioPlayer.onDurationChanged.listen(
      (duration) => setState(() {
        _duration = duration;
      }),
    );

    // Set the audio source (local file or URL)
    _audioPlayer.setSource(_source);

    super.initState();
  }

  @override
  void dispose() {
    // Cancel subscriptions and dispose audio player
    _playerStateChangedSubscription.cancel();
    _positionChangedSubscription.cancel();
    _durationChangedSubscription.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Main UI: Row with play/pause, slider, and delete button
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                _buildControl(), // Play/Pause button
                _buildSlider(constraints.maxWidth), // Seek slider
                IconButton(
                  icon: const Icon(Icons.delete, size: _deleteBtnSize),
                  onPressed: () {
                    // Stop playback before deleting if necessary
                    if (_audioPlayer.state == ap.PlayerState.playing) {
                      stop().then((value) => widget.onDelete());
                    } else {
                      widget.onDelete();
                    }
                  },
                ),
              ],
            ),
            // Display total duration for debugging
            Text('${_duration ?? 0.0}'),
          ],
        );
      },
    );
  }

  /// Builds the play/pause control button
  Widget _buildControl() {
    Icon icon;
    Color color;

    // Show pause button if playing, otherwise play button
    if (_audioPlayer.state == ap.PlayerState.playing) {
      icon = const Icon(Icons.pause, size: 30);
      color = Colors.red.withValues(alpha: 0.1);
    } else {
      final theme = Theme.of(context);
      icon = Icon(Icons.play_arrow, size: 30);
      color = theme.primaryColor.withValues(alpha: 0.1);
    }

    // Circular button with ripple effect
    return ClipOval(
      child: Material(
        color: color,
        child: InkWell(
          child: SizedBox(width: _controlSize, height: _controlSize, child: icon),
          onTap: () {
            // Toggle play/pause
            if (_audioPlayer.state == ap.PlayerState.playing) {
              pause();
            } else {
              play();
            }
          },
        ),
      ),
    );
  }

  /// Builds the seek slider for audio playback
  Widget _buildSlider(double widgetWidth) {
    bool canSetValue = false;
    final duration = _duration;
    final position = _position;

    // Enable slider only if duration and position are valid
    if (duration != null && position != null) {
      canSetValue = position.inMilliseconds > 0;
      canSetValue &= position.inMilliseconds < duration.inMilliseconds;
    }

    // Calculate slider width based on available space
    double width = widgetWidth - _controlSize - _deleteBtnSize;
    width -= _deleteBtnSize;

    return SizedBox(
      width: width,
      child: Slider(
        activeColor: Theme.of(context).primaryColor, // Uses theme's primary color
        inactiveColor: Theme.of(context).colorScheme.secondary, // Uses theme's secondary color
        onChanged: (v) {
          // Seek to new position in audio
          if (duration != null) {
            final position = v * duration.inMilliseconds;
            _audioPlayer.seek(Duration(milliseconds: position.round()));
          }
        },
        value: canSetValue && duration != null && position != null ? position.inMilliseconds / duration.inMilliseconds : 0.0,
      ),
    );
  }

  /// Starts audio playback
  Future<void> play() => _audioPlayer.play(_source);

  /// Pauses audio playback
  Future<void> pause() async {
    await _audioPlayer.pause();
    setState(() {});
  }

  /// Stops audio playback
  Future<void> stop() async {
    await _audioPlayer.stop();
    setState(() {});
  }

  /// Returns the correct audio source type for web or device
  Source get _source => kIsWeb ? ap.UrlSource(widget.source) : ap.DeviceFileSource(widget.source);
}
