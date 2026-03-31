import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';

import 'platform/audio_recorder_platform.dart';

class Recorder extends StatefulWidget {
  final void Function(String path) onStop;

  const Recorder({super.key, required this.onStop});

  @override
  State<Recorder> createState() => _RecorderState();
}

class _RecorderState extends State<Recorder> with AudioRecorderMixin {
  int _recordDuration = 0; // Duration of the current recording in seconds
  Timer? _timer; // Timer to update the recording duration every second
  late final AudioRecorder _audioRecorder; // AudioRecorder instance for handling recording
  StreamSubscription<RecordState>? _recordSub; // Subscription to recording state changes
  RecordState _recordState = RecordState.stop; // Current state of the recorder (record, pause, stop)
  StreamSubscription<Amplitude>? _amplitudeSub; // Subscription to amplitude (volume) changes
  Amplitude? _amplitude; // Current amplitude (volume) data

  @override
  void initState() {
    // Initialize the audio recorder instance
    _audioRecorder = AudioRecorder();

    // Listen for changes in the recording state (start, pause, stop)
    _recordSub = _audioRecorder.onStateChanged().listen((recordState) {
      _updateRecordState(recordState);
    });

    // Listen for amplitude (volume) changes every 300ms and update UI
    _amplitudeSub = _audioRecorder.onAmplitudeChanged(const Duration(milliseconds: 300)).listen((amp) {
      setState(() => _amplitude = amp);
    });

    // Call the parent class's initState
    super.initState();
  }

  /// Starts a new audio recording session if permissions and encoder support are available.
  /// Configures the recorder, resets the timer, and begins recording to a file.
  Future<void> _start() async {
    try {
      // Check for audio recording permission
      if (await _audioRecorder.hasPermission()) {
        // Set the audio encoder to AAC-LC
        const encoder = AudioEncoder.aacLc;

        // Check if the encoder is supported on this device
        if (!await _isEncoderSupported(encoder)) {
          return;
        }

        // List available input devices (microphones) and print for debugging
        final devs = await _audioRecorder.listInputDevices();
        debugPrint(devs.toString());

        // Configure recording: use AAC-LC encoder and mono channel
        const config = RecordConfig(encoder: encoder, numChannels: 1);

        // Start recording to a file
        await recordFile(_audioRecorder, config); 

        // (Optional) Start recording to a stream instead of a file
        // await recordStream(_audioRecorder, config);
      }
    } catch (e) {
      // Print any errors in debug mode
      if (kDebugMode) {
        print(e);
      }
    }
  }

  /// Stops the current audio recording session, notifies the parent widget, and handles post-processing.
  Future<void> _stop() async {
    // Stop the recording and get the file path where the audio was saved
    final path = await _audioRecorder.stop();

    // If a valid file path is returned
    if (path != null) {
      // Notify the parent widget with the file path
      widget.onStop(path);
    }
  }

  /// Updates the recorder's state and manages the timer based on the new recording state.
  /// Ensures the UI and timer reflect the current state (record, pause, stop).
  void _updateRecordState(RecordState recordState) {
    // Update the internal state and trigger a UI update
    setState(() => _recordState = recordState);
    debugPrint('Record state changed: $recordState');

    // Handle timer and duration based on the new state
    switch (recordState) {
      case RecordState.pause:
        // Pause: stop the timer (stop updating duration)
        _timer?.cancel();
        break;
      case RecordState.record:
        // Record: start or resume the timer (update duration every second)
        _timer?.cancel();
        _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
          setState(() => _recordDuration++);
        });
        break;
      case RecordState.stop:
        // Stop: cancel the timer and reset the duration counter
        _timer?.cancel();
        _recordDuration = 0;
        break;
    }
  }

  Future<bool> _isEncoderSupported(AudioEncoder encoder) async {
    final isSupported = await _audioRecorder.isEncoderSupported(
      encoder,
    );

    if (!isSupported) {
      debugPrint('${encoder.name} is not supported on this platform.');
      debugPrint('Supported encoders are:');

      for (final e in AudioEncoder.values) {
        if (await _audioRecorder.isEncoderSupported(e)) {
          debugPrint('- ${e.name}');
        }
      }
    }
    return isSupported;
  }

  @override
  /// Builds the UI for the Recorder widget.
  /// Displays recording controls, timer, and amplitude (volume) feedback.
  Widget build(BuildContext context) {
    // Main vertical layout
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Row of controls: record/stop, pause/resume, and timer/text
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _buildRecordStopControl(), // Record or stop button
          ],
        ),
        // Show amplitude (volume) feedback if available
        if (_amplitude != null) ...[
          const SizedBox(height: 40),
          _buildTimer(), // Current record duration
          Text('Current amplitude: ${(_amplitude?.current ?? 0.0).toStringAsFixed(1)}'), // Current amplitude
          Text('Max amplitude: ${_amplitude?.max ?? 0.0}'), // Maximum amplitude
        ],
      ],
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recordSub?.cancel();
    _amplitudeSub?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  Widget _buildRecordStopControl() {
    late Icon icon;
    Color iconColor = Colors.white;

    if (_recordState != RecordState.stop) {
      icon = Icon(Icons.stop, color: iconColor, size: 30);
    } else {
      icon = Icon(Icons.mic, color: iconColor, size: 30);
    }

    return ClipOval(
      child: Material(
        color: null,
        child: InkWell(
          child: SizedBox(width: 56, height: 56, child: icon),
          onTap: () async {
            if (_recordState != RecordState.stop) {
              await _stop();
            } else {
              await _start();
            }
          },
        ),
      ),
    );
  }

  Widget _buildTimer() {
    final String minutes = _formatNumber(_recordDuration ~/ 60);
    final String seconds = _formatNumber(_recordDuration % 60);

    return Text(
      'Duration: $minutes : $seconds',
      style: const TextStyle(color: Colors.white),
    );
  }

  String _formatNumber(int number) {
    String numberStr = number.toString();
    if (number < 10) {
      numberStr = '0$numberStr';
    }
    return numberStr;
  }
}
