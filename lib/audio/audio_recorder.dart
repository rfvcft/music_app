import 'dart:async';
import 'dart:math';

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';

import 'package:path_provider/path_provider.dart';
import 'package:music_app/utils/conversion.dart' as conv;
import 'package:music_app/main.dart' show routeObserver;
import 'platform/audio_recorder_platform.dart';

class Recorder extends StatefulWidget {
  final void Function(String path) onStop;

  const Recorder({super.key, required this.onStop, required this.width, required this.height, this.isLandscape = false});

  final double width;
  final double height;
  final bool isLandscape;

  @override
  State<Recorder> createState() => _RecorderState();
}

class _RecorderState extends State<Recorder> with AudioRecorderMixin, RouteAware {
  String? _nextRecordingName; // Name for the next recording
  int _recordDurationMs = 0; // Duration of the current recording in milliseconds
  Timer? _timer; // Timer to update the recording duration every second
  late final AudioRecorder
  _audioRecorder; // AudioRecorder instance for handling recording
  StreamSubscription<RecordState>?
  _recordSub; // Subscription to recording state changes
  RecordState _recordState =
      RecordState.stop; // Current state of the recorder (record, pause, stop)
  StreamSubscription<Amplitude>?
  _amplitudeSub; // Subscription to amplitude (volume) changes
  Amplitude? _amplitude; // Current amplitude (volume) data
  double? _smoothedAmplitude; // Smoothed amplitude for visual display
  static const double _smoothingFactor = 0.25; // 0 = no change, 1 = instant

  @override
  void initState() {
    // Initialize the audio recorder instance
    _audioRecorder = AudioRecorder();

    // Listen for changes in the recording state (start, pause, stop)
    _recordSub = _audioRecorder.onStateChanged().listen((recordState) {
      _updateRecordState(recordState);
    });

    // Listen for amplitude (volume) changes every 300ms and update UI
    _amplitudeSub = _audioRecorder
        .onAmplitudeChanged(const Duration(milliseconds: 50))
        .listen((amp) {
          setState(() {
            _amplitude = amp;
            if (_smoothedAmplitude == null) {
              _smoothedAmplitude = amp.current;
            } else {
              _smoothedAmplitude = _smoothedAmplitude! +
                  _smoothingFactor * (amp.current - _smoothedAmplitude!);
            }
          });
          //debugPrint('Current amplitude: ${amp.current}, Smoothed amplitude: $_smoothedAmplitude');
        });

    // Call the parent class's initState
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is ModalRoute<void>) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() {
    // Another route was pushed on top — stop recording if active
    if (_recordState != RecordState.stop) {
      _stop();
    }
  }

  @override
  void didPop() {
    // This route was popped (e.g. back navigation) — stop recording if active
    if (_recordState != RecordState.stop) {
      _stop();
    }
  }

  /// Starts a new audio recording session if permissions and encoder support are available.
  /// Configures the recorder, resets the timer, and begins recording to a file.
  Future<void> _start() async {
    // Compute and set the next recording name before starting
    final newName = await _findNextRecordingName();
    setState(() {
      _nextRecordingName = newName;
    });
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

    if (path != null) {
      try {
        final originalFile = File(path);
        String? newName = _nextRecordingName;
        String newPath;
        if (newName != null) {
          final dir = originalFile.parent;
          newPath = dir.path + Platform.pathSeparator + newName;
        } else {
          // fallback: generate a new name if for some reason _nextRecordingName is null
          final ext = originalFile.path.split('.').last;
          newName = await _findNextRecordingName(extension: ext);
          final dir = originalFile.parent;
          newPath = dir.path + Platform.pathSeparator + newName;
        }
        await originalFile.rename(newPath);
        widget.onStop(newPath);
      } catch (e) {
        // Fallback: if renaming fails, use the original path
        widget.onStop(path);
      }
    }
    _amplitude = null; // Reset amplitude data for next recording
    _smoothedAmplitude = null; // Reset smoothed amplitude for next recording
    // Clear the next recording name after stopping
    if (mounted) {
      setState(() {
        _nextRecordingName = null;
      });
    }
  }

  /// Returns the next available recording file name in the documents directory.
  Future<String> _findNextRecordingName({String? extension}) async {
    final dir = await getApplicationDocumentsDirectory();
    String baseName = 'New Recording';
    String ext = extension ?? 'm4a';
    int counter = 1;
    String newName;
    File newFile;
    do {
      newName = '$baseName $counter.$ext';
      newFile = File(dir.path + Platform.pathSeparator + newName);
      counter++;
    } while (await newFile.exists());
    return newName;
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
        // Record: start or resume the timer (update duration every 20ms)
        _timer?.cancel();
        _timer = Timer.periodic(const Duration(milliseconds: 20), (Timer t) {
          setState(() => _recordDurationMs += 20);
        });
        break;
      case RecordState.stop:
        // Stop: cancel the timer and reset the duration counter
        _timer?.cancel();
        _recordDurationMs = 0;
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
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        children: [
          Align(
            alignment: widget.isLandscape ? const Alignment(0, -1/3) : Alignment.center,
            child: _buildRecordStopControl(),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildRecordingStatusText(),
                const SizedBox(height: 10),
                _buildTimer(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _timer?.cancel();
    _recordSub?.cancel();
    _amplitudeSub?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  Widget _buildRecordStopControl() {
    final double screenRadius = (widget.width < widget.height ? widget.width : widget.height) / 2; // Maximum radius available on the screen

    const double minAmplitude = -65.0; // Minimum amplitude in dB (silence)
    const double maxAmplitude = 0.0; // Maximum amplitude in dB (loudest)
    final double normalizedAmplitude = (((_smoothedAmplitude ?? minAmplitude) - minAmplitude) / (maxAmplitude - minAmplitude)).clamp(0.0, 1.0); // Normalize smoothed amplitude to [0.0, 1.0] for UI scaling

    const double iconSize = 36; // Size of the mic/stop icon in the center
    final double diskRadius = screenRadius * 0.25; // Radius of the static inner disk with the icon

    final double minRingWidth = screenRadius * 0.025; // Minimum width for the ring to ensure visibility even at low amplitudes
    final double maxRingWidth = screenRadius * 0.3; // Max ring width based on available space
    final double ringWidth = minRingWidth + normalizedAmplitude * (maxRingWidth - minRingWidth); // Width of the ring that grows with amplitude

    final double totalRadius = diskRadius + ringWidth;
    final double totalDiameter = totalRadius * 2;

    double initialStartIntensity = 0.9;
    double initialEndIntensity = 0.9;
    double startIntensity = initialStartIntensity + normalizedAmplitude * (1.0 - initialStartIntensity); // Intensity for the innermost color of the ring, increases with amplitude
    double endIntensity = initialEndIntensity + sqrt(normalizedAmplitude) * (0.0 - initialEndIntensity); // Intensity for the outermost color of the ring, decreases with amplitude 

    const Color iconColor = Colors.white;
    late Icon icon;

    if (_recordState != RecordState.stop) {
      icon = Icon(Icons.graphic_eq, color: iconColor, size: iconSize);
    } else {
      icon = Icon(Icons.mic, color: iconColor, size: iconSize);
    }
    
    int numberOfStops = 10;
    List<Color> colors = List.generate(numberOfStops, (index) {
      double intensity = startIntensity + (index / (numberOfStops - 1)) * (endIntensity - startIntensity);
      return conv.infernoColormap(intensity);
    });
    List<double> stops = List.generate(numberOfStops, (index) => (diskRadius +  (index / (numberOfStops - 1)) * ringWidth) / totalRadius);

    // Layout size is based on the disk only; the ring overflows visually.
    return SizedBox(
      width: diskRadius * 2,
      height: diskRadius * 2,
      child: OverflowBox(
        maxWidth: totalDiameter,
        maxHeight: totalDiameter,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Radial gradient ring (only in recording mode)
            if (_recordState == RecordState.record)
              Container(
                width: totalDiameter,
                height: totalDiameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: colors,
                    stops: stops,
                    center: Alignment.center,
                    radius: 0.5,
                  ),
                ),
              )
            else
              Container(
                width: 2 * (diskRadius + minRingWidth), // Static ring size when not recording
                height: 2 * (diskRadius + minRingWidth),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey, width: ringWidth),
                ),
              ),
            // Disk with icon
            ClipOval(
              child: Material(
                color: Colors.black,
                child: InkWell(
                  child: SizedBox(
                    width: diskRadius * 2,
                    height: diskRadius * 2,
                    child: Center(child: icon),
                  ),
                  onTap: () async {
                    if (_recordState != RecordState.stop) {
                      await _stop();
                    } else {
                      await _start();
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingStatusText() {
    if (_recordState == RecordState.record && _nextRecordingName != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 12.0),
        child: Text(
          _nextRecordingName!.replaceFirst(RegExp(r'\.[^.]+$'), ''),
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      );
    } else if (_recordState == RecordState.stop) {
      return const Padding(
        padding: EdgeInsets.only(top: 12.0),
        child: Text(
          'Waiting to record',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget _buildTimer() {
    if (_recordState == RecordState.stop) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.0),
        child: Text(
          'Recording quality affects analysis.\nImporting a studio recording is preferred.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
      );
    }

    final int totalMs = _recordDurationMs;
    final String minutes = _formatNumber(totalMs ~/ 60000);
    final String seconds = _formatNumber((totalMs ~/ 1000) % 60);
    final String millis = _formatNumber((totalMs % 1000) ~/ 10);

    return Text(
      '$minutes:$seconds:$millis',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
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
