import 'dart:ffi';
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:music_app/utils/conversion.dart' as conv; // Conversion utilities
import 'package:music_app/utils/constants.dart' as cnst; // Constants (music related, colors, etc.)
import 'package:music_app/utils/intensity_bar.dart' as ib; // Intensity bar widget


// Builds non-interactive parts of the chromagram visualization
class ChromagramBuilder {
    final VoidCallback onEditMusicalKey;
    final ValueChanged<double> onSliderChanged;
    final ValueChanged<double> onSliderChangeStart;
    final ValueChanged<double> onSliderChangeEnd;
    final VoidCallback onPlayButtonPressed;
    final VoidCallback onPlayButtonReset;
    ChromagramBuilder({
      required double duration,
      required List<List<double>> chromagram,
      required this.onEditMusicalKey,
      required this.onSliderChanged,
      required this.onSliderChangeStart,
      required this.onSliderChangeEnd,
      required this.onPlayButtonPressed,
      required this.onPlayButtonReset,
    }) :
        _duration = duration,
        _chromagram = chromagram,
        _numBins = chromagram.length,
        _numFrames = chromagram[0].length;

  // Invariant parameters
  final double _duration; // Duration of audio in seconds 
  final List<List<double>> _chromagram; // Chromagram (bins x time frames)
  final int _numBins;
  final int _numFrames;

  // Builds the chromagram visualization as a list of widgets
  List<Widget> buildChromagram({
    required BuildContext context,
    required double availableWidthPx,
    required double availableHeightPx,
    required double currentTime, // Current playback time in seconds
    required double leftShift, // Shift of chromagram to the left. Range [0.0, 1.0]
    required bool isPortrait, // Whether the device is in portrait or landscape orientation
    required bool isPlaying, // Whether the audio is currently playing (for play/pause button)
    required bool isComplete, // Wheter the audio playback is complete (for reset button)
    required String musicalKey, // Musical key of the audio (e.g., "C major", "A minor")
    required int tonicIndex, // Pitch class of tonic (0-11)
    required String scale, // Scale type (e.g., "major", "minor")
  }) {
    // Update current parameters
    if (_musicalKey != musicalKey) {
      _musicalKey = musicalKey;
      _tonicIndex = tonicIndex;
      _scale = scale;
      _numberOfNotesInScale = _getNumberOfNotesInScale(tonicIndex, scale);
    }
    _context = context;
    _availableWidthPx =availableWidthPx;
    _availableHeightPx = availableHeightPx;
    _currentTime = currentTime;
    _leftShift = leftShift;
    _isPortrait = isPortrait;
    _isPlaying = isPlaying;
    _isComplete = isComplete;

    print('Building chromagram with parameters:');
    print('Available width (px): $_availableWidthPx');
    print('Available height (px): $_availableHeightPx');
    print('Current time (s): $_currentTime');
    print('Left shift: $_leftShift');
    print('Is portrait: $_isPortrait');
    print('Tonic index: $_tonicIndex');
    print('Scale: $_scale');

    // Update derived parameters
    _numSecondsAboveCurrent = _isPortrait! ? 5 : 4; // Number of seconds to display above current line
    _numberOfNotesToDisplay = _isPortrait! ? 12 : 35; // How many notes to display

    _heightAboveCurrentPx = _isPortrait! ? cnst.goldenFactorLarge * _availableHeightPx! : 0.75 * _availableHeightPx!; // Available height above current line
    _heightBelowCurrentPx = _isPortrait! ? cnst.goldenFactorSmall * _availableHeightPx! : 0.25 * _availableHeightPx!; // Available height below current line

    _oneSecondPx = _heightAboveCurrentPx / _numSecondsAboveCurrent; // One second in pixels
    _durationPx = _duration * _oneSecondPx; // Total duration in pixels
    _currentTimePx = _currentTime! * _oneSecondPx; // Current time in pixels

    _currentLinePx = _heightBelowCurrentPx; // Distance of current line from bottom of screen
    _sliderLinePx = _isPortrait! ? cnst.goldenFactorLarge * _heightBelowCurrentPx : 0.0; // Distance of slider line from bottom of screen (not used in landscape mode)

    _deltaWidthPx = _availableWidthPx! / (2 + _numberOfNotesToDisplay - 1 + 2); // Horizontal offset for vertical lines 
    _deltaHeightPx = _isPortrait! ? cnst.goldenFactorLarge * (_currentLinePx - _sliderLinePx) : 0.6 * _heightBelowCurrentPx; // Vertical offset between current line and bottom line

    _bottomLinePx = _currentLinePx - _deltaHeightPx; // Distance of bottom line from bottom of screen 
    _chromaBlockerPx = _availableHeightPx! - _bottomLinePx; // Height of chroma blocker from top of screen

    _playButtonPx = _isPortrait! ? (_availableHeightPx! - _sliderLinePx) + 0.15 * _sliderLinePx : 0.0; // Distance of top of audio player to top of screen
    _timeDisplayPx = _isPortrait! ? (_availableHeightPx! - _sliderLinePx) + 0.05 * _sliderLinePx : 0.0; // Distance of top of time display to top of screen (not used in landscape mode)

    _pitchLabelPx = (_availableHeightPx! - _currentLinePx); // Distance of top of pitch labels from bottom of screen
    _keyTextPx = _isPortrait! ? (_availableHeightPx! - _currentLinePx) + 0.075 * _currentLinePx : (_availableHeightPx! - _currentLinePx) + 0.3 * _currentLinePx; // Distance of key text from top of screen
    
    _leftShiftToPx =  ((_isPortrait! ? _numberOfNotesInScale : _numBins) - _numberOfNotesToDisplay) * _deltaWidthPx; // Maximum horizontal shift in pixels (when leftShift = 1.0)
    _leftShiftPx = leftShift * _leftShiftToPx; // Horizontal shift to the left (based on leftShift)

    List<Widget> chromagramWidgets = [];
    chromagramWidgets.addAll(_pitchIntensityBars());
    chromagramWidgets.addAll(_verticalPitchLines());
    chromagramWidgets.add(_horizontalLine(position: 'start'));
    chromagramWidgets.add(_horizontalLineLeftBoundary(position: 'start'));
    chromagramWidgets.add(_horizontalLineRightBoundary(position: 'start'));

    chromagramWidgets.add(_horizontalLine(position: 'end'));
    chromagramWidgets.add(_horizontalLineLeftBoundary(position: 'end'));
    chromagramWidgets.add(_horizontalLineRightBoundary(position: 'end'));

    chromagramWidgets.add(_keyText());

    chromagramWidgets.add(_chromaBlocker());
    chromagramWidgets.addAll(_pitchLabels());

    chromagramWidgets.add(_currentLine());
    chromagramWidgets.add(_rightArrow());

    chromagramWidgets.add(_timeDisplay());
    chromagramWidgets.add(_slider());
    chromagramWidgets.add(_playButton());

    return chromagramWidgets;
  }

  // Current parameters
  BuildContext? _context;
  double? _availableWidthPx;
  double? _availableHeightPx;
  double? _currentTime;
  double? _leftShift;
  bool? _isPortrait;
  bool? _isPlaying;
  bool? _isComplete;
  String? _musicalKey;
  int? _tonicIndex;
  String? _scale;

  // Derived parameters
  late int _numberOfNotesInScale; // How many notes in range [0, numBins) are in the scale
  late int _numSecondsAboveCurrent; // Number of seconds to display above current line
  late int _numberOfNotesToDisplay;

  late double _heightAboveCurrentPx; // Available height above current line
  late double _heightBelowCurrentPx; // Available height below current line

  late double _oneSecondPx; // One second in pixels
  late double _durationPx; // Total duration in pixels
  late double _currentTimePx; // Current time in pixels

  late double _currentLinePx; // Distance of current line from bottom of screen
  late double _sliderLinePx; // Distance of slider line from bottom of screen (not used in landscape mode)

  late double _deltaWidthPx; // Horizontal unit in pixels (e.g., distance of one intensity block to the next)
  late double _deltaHeightPx; // Vertical unit in pixels (e.g., vertical offset between current line and bottom line)

  late double _playButtonPx; // Distance of top of audio player to top of screen
  late double _timeDisplayPx; // Distance of top of time display to top of screen (not used in landscape mode)

  late double _bottomLinePx; // Distance of bottom line from bottom of screen
  late double _chromaBlockerPx; // Distance of chroma blocker from top of screen

  late double _pitchLabelPx; // Distance of top of labels from bottom of screen
  late double _keyTextPx; // Distance of key text from top of screen

  late double _leftShiftToPx; // Maximum left shift in pixels (when leftShift is 1.0)
  late double _leftShiftPx; // Current left shift in pixels

  int _getNumberOfNotesInScale(int tonicIndex, String scale) {
    final scalePattern = cnst.scalePatterns[scale];
    int count = 0;
    for (int i = 0; i < _numBins; i++) {
      final isInScale = scalePattern != null && scalePattern[(i - tonicIndex) % cnst.numPitches] == 1;
      if (isInScale) count++;
    }
    return count;
  }

  // Chromagram pitch intensity bars
  List<Widget> _pitchIntensityBars() {
    List<Widget> pitchIntensityBars = [];

    // Parameters for restricting drawing within visual window
    double safetyMarginPx = 0.5 * _oneSecondPx; // Safety margin in pixels (we draw a few extra pixels above and below visual window)
    double heightAboveCurrentSeconds = _heightAboveCurrentPx / _oneSecondPx; // Height above current line in seconds
    double deltaHeightSeconds = _deltaHeightPx / _oneSecondPx; 
    double safetyMarginSeconds = safetyMarginPx / _oneSecondPx; 
    int safetyMarginFrames = (safetyMarginSeconds / (_duration / _numFrames)).ceil(); // Safety margin in frames
    int startIndex = max(0, ((_currentTime! - deltaHeightSeconds) / _duration * _numFrames).ceil() - safetyMarginFrames); // Index of first frame to display, with safety margin
    int endIndex = min(_numFrames, ((_currentTime! + heightAboveCurrentSeconds) / _duration * _numFrames).floor() + safetyMarginFrames); // Index of last frame to display, with safety margin

    int currentNumberOfPitchBars = 0; // Counter needed for only displaying notes within scale (in portrait mode)
    double pitchBarWidthPx = 0.5 * _deltaWidthPx; // Width of each pitch intensity bar in pixels
    final scalePattern = cnst.scalePatterns[_scale];
    for (int i = 0; i < _numBins; i++) {
      final isInScale = scalePattern != null && scalePattern[(i - _tonicIndex!) % cnst.numPitches] == 1; // Determine if pitch class is in scale
      if (_isPortrait! && !isInScale) continue; // In portrait mode, only show pitch classes in the scale to reduce clutter
      currentNumberOfPitchBars++;
      double centerOfPitchBarPx = (currentNumberOfPitchBars + 1) * _deltaWidthPx - _leftShiftPx; // Center of pitch bar in pixels
      if (centerOfPitchBarPx < 0 || centerOfPitchBarPx > _availableWidthPx!) {
        continue; // Skip drawing pitch bars that are completely outside of the visual window
      }
      double opacityOfPitchBar = 1.0; // Fade out pitch bar at boundary 
      if (centerOfPitchBarPx < 2 * _deltaWidthPx) {
        opacityOfPitchBar = ((centerOfPitchBarPx - _deltaWidthPx) / _deltaWidthPx).clamp(0.0, 1.0);
      } else if (centerOfPitchBarPx > (_availableWidthPx! - 2 * _deltaWidthPx)) {
        opacityOfPitchBar = ((_availableWidthPx! - _deltaWidthPx - centerOfPitchBarPx) / _deltaWidthPx).clamp(0.0, 1.0);
      }
      Widget pitchIntensityBar = Positioned(
        left: centerOfPitchBarPx - pitchBarWidthPx / 2,
        bottom: _currentLinePx, 
        child: Transform.translate(
          offset: Offset(0, _currentTimePx),  // Translate vertically down based on current playback time
          child: Opacity(
            opacity: opacityOfPitchBar,
            child: ib.IntensityBar(
              values: _chromagram[i],
              orientation: 'vertical',
              width: pitchBarWidthPx, 
              height: _durationPx,
              startIndex: startIndex,
              endIndex: endIndex,
              enhancedResolution: false, 
            ),
          ),
        ),
      );
      pitchIntensityBars.add(pitchIntensityBar);
    }
    return pitchIntensityBars;
  }

  // Vertical lines for each pitch 
  List<Widget> _verticalPitchLines() {
    List<Widget> verticalPitchLines = [];
    double topOfVerticalPitchLinePx = (_availableHeightPx! - _currentLinePx) - (_durationPx - _currentTimePx);
    int currentNumberOfNotes = 0;
    final scalePattern = cnst.scalePatterns[_scale];
    for (int i = 0; i < _numBins; i++) {
      final isInScale = scalePattern != null && scalePattern[(i - _tonicIndex!) % cnst.numPitches] == 1; // Determine if pitch class is in scale
      if (_isPortrait! && !isInScale) continue; // In portrait mode, only show pitch classes in the scale to reduce clutter
      currentNumberOfNotes++;
      double centerOfVerticalPitchLinePx = (currentNumberOfNotes + 1) * _deltaWidthPx - _leftShiftPx;
      if (centerOfVerticalPitchLinePx < _deltaWidthPx || centerOfVerticalPitchLinePx > (_availableWidthPx! - _deltaWidthPx)) {
        continue; // Skip drawing vertical lines that are completely outside of the visual window
      }
      double opacityOfVerticalPitchLine = 1.0;
      if (centerOfVerticalPitchLinePx < 2 * _deltaWidthPx) {
        opacityOfVerticalPitchLine = ((centerOfVerticalPitchLinePx - _deltaWidthPx) / _deltaWidthPx).clamp(0.0, 1.0);
      } else if (centerOfVerticalPitchLinePx > (_availableWidthPx! - 2 * _deltaWidthPx)) {
        opacityOfVerticalPitchLine = ((_availableWidthPx! - _deltaWidthPx - centerOfVerticalPitchLinePx) / _deltaWidthPx).clamp(0.0, 1.0);
      }
      Widget verticalPitchLine = Positioned(
        left: centerOfVerticalPitchLinePx,
        width: 1,
        bottom: _currentLinePx - min(_currentTimePx, _deltaHeightPx), 
        top: max(topOfVerticalPitchLinePx, 0),
        child: Opacity(
          opacity: opacityOfVerticalPitchLine,
          child: Container(
            width: 1,
            color: isInScale ? Colors.grey[400]! : Colors.grey[900]!, // Lighter vertical line for pitch classes in the scale, darker for those not in the scale
          ),
        ),
      );
      verticalPitchLines.add(verticalPitchLine);
    }
    return verticalPitchLines;
  }

  // Horizontal line for the start and end of the chromagram
  Widget _horizontalLine({required String position}) {
    late double bottomPx;
    late double offsetPx;
    double leftPx = 2*_deltaWidthPx - _leftShiftPx;
    double rightPx = _availableWidthPx! - (2 * _deltaWidthPx - _leftShiftPx + ((_isPortrait! ? _numberOfNotesInScale : _numBins) - 1) * _deltaWidthPx);
    if (position == 'start'){
      bottomPx = _currentLinePx;
      offsetPx = min(_currentTimePx, _deltaHeightPx);
    } else if (position == 'end') {
      bottomPx = _currentLinePx + _durationPx;
      offsetPx = _currentTimePx;
    } else {
      throw ArgumentError('Invalid position for horizontal line: $position');
    }
    return Positioned(
      left: max(leftPx, 2 * _deltaWidthPx),
      right: max(rightPx, 2 * _deltaWidthPx),
      bottom: bottomPx,
      child: Transform.translate(
        offset: Offset(0, offsetPx), 
        child: Container(
          height: 1,
          color: Colors.grey,
        ),
      ),
    );
  }

  // Left boundary of horizontal line (fades out with a gradient)
  Widget _horizontalLineLeftBoundary({required String position}) {
    late double bottomPx;
    late double offsetPx;
    double leftPx = 2 * _deltaWidthPx - _leftShiftPx;
    if (position == 'start'){
      bottomPx = _currentLinePx;
      offsetPx = min(_currentTimePx, _deltaHeightPx);
    } else if (position == 'end') {
      bottomPx = _currentLinePx + _durationPx;
      offsetPx = _currentTimePx;
    } else {
      throw ArgumentError('Invalid position for horizontal line: $position');
    }
    return Positioned(
      left: max(leftPx, _deltaWidthPx),
      right: _availableWidthPx! - 2 * _deltaWidthPx,
      bottom: bottomPx,
      child: Transform.translate(
        offset: Offset(0, offsetPx), 
        child: Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.center,
              end: Alignment.centerLeft,
              colors: [
                Colors.grey,
                Colors.grey.withValues(alpha: 0.25),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Right boundary of horizontal line (fades out with a gradient)
  Widget _horizontalLineRightBoundary({required String position}) {
    late double bottomPx;
    late double offsetPx;
    double widthPx = ((_isPortrait! ? _numberOfNotesInScale : _numBins) - _numberOfNotesToDisplay) * _deltaWidthPx - _leftShiftPx;
    if (position == 'start'){
      bottomPx = _currentLinePx;
      offsetPx = min(_currentTimePx, _deltaHeightPx);
    } else if (position == 'end') {
      bottomPx = _currentLinePx + _durationPx;
      offsetPx = _currentTimePx;
    } else {
      throw ArgumentError('Invalid position for horizontal line: $position');
    }
    return Positioned(
      left: _availableWidthPx! - 2 * _deltaWidthPx,
      bottom: bottomPx,
      child: Transform.translate(
        offset: Offset(0, offsetPx),
        child: Container(
          height: 1,
          width: min(widthPx, _deltaWidthPx),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.center,
              end: Alignment.centerRight,
              colors: [
                Colors.grey,
                Colors.grey.withValues(alpha: 0.25),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chromaBlocker() {
    return Positioned(
      top: _chromaBlockerPx,
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        color: Colors.black,
      ),
    );
  }

  List<Widget> _pitchLabels() {
    List<Widget> pitchLabels = [];
    int currentNumberOfPitchLabels = 0;
    final scalePattern = cnst.scalePatterns[_scale];
    for (int i = 0; i < _numBins; i++) {
      // Add pitch class label below startLine, translated with currentTimePx
      // Determine if pitch is in scale
      
      final isInScale = scalePattern != null && scalePattern[(i - _tonicIndex!) % cnst.numPitches] == 1;
      if (_isPortrait! && !isInScale) continue; // In portrait mode, only show pitch classes in the scale to reduce clutter
      currentNumberOfPitchLabels++;
      double centerOfPitchLabelPx = (currentNumberOfPitchLabels + 1) * _deltaWidthPx - _leftShiftPx;
      if (centerOfPitchLabelPx < _deltaWidthPx || centerOfPitchLabelPx > (_availableWidthPx! - _deltaWidthPx)) {
        continue; // Skip drawing pitch labels that are completely outside of the visual window
      }
      double opacityOfPitchLabel = 1.0;
      if (centerOfPitchLabelPx < 2 * _deltaWidthPx) {
        opacityOfPitchLabel = ((centerOfPitchLabelPx - _deltaWidthPx) / _deltaWidthPx).clamp(0.0, 1.0);
      } else if (centerOfPitchLabelPx > (_availableWidthPx! - 2 * _deltaWidthPx)) {
        opacityOfPitchLabel = ((_availableWidthPx! - _deltaWidthPx - centerOfPitchLabelPx) / _deltaWidthPx).clamp(0.0, 1.0);
      }
      Widget pitchLabel = Positioned(
        left: centerOfPitchLabelPx - 16, // Center label under line
        top: _pitchLabelPx,
        child: Transform.translate(
          offset: Offset(0, min(_currentTimePx, _deltaHeightPx)),
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
      pitchLabels.add(pitchLabel);
    }
    return pitchLabels;
  }

  Widget _currentLine() {
    return Positioned(
      // Align the center of the line with currentLinePx
      bottom: _currentLinePx,
      left: _deltaWidthPx,
      right: _deltaWidthPx,
      child: Container(
        height: 1, // Originally 1
        color: Colors.white,
      ),
    );
  }

  Widget _rightArrow() {
    double iconSize = 30;
    return Positioned(
      bottom: _currentLinePx - iconSize / 2 + 0.5, // +0.5 shift to center (experimentally determined)
      left: _deltaWidthPx - iconSize / 2,
      child: Icon(
        Icons.play_arrow,
        color: Colors.white,
        size: iconSize,
      ),
    );
  }

  // Widget to display current time and total duration aligned with slider ends
  Widget _timeDisplay() {
    if (!_isPortrait!) return SizedBox.shrink(); // Only show time display in portrait mode
    return Positioned(
      left: _deltaWidthPx,
      right: _deltaWidthPx,
      top: _timeDisplayPx,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            conv.formatTime(_currentTime!),
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          Text(
            conv.formatTime(_duration),
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _slider() {
    if (!_isPortrait!) return SizedBox.shrink(); // Only show slider in portrait mode
    double sliderRadius = 8; 
    return Positioned(
        left: _deltaWidthPx - sliderRadius,
        right: _deltaWidthPx - sliderRadius,
        bottom: _sliderLinePx - sliderRadius,
        child: SliderTheme(
        data: SliderTheme.of(_context!).copyWith(
          trackShape: const RoundedRectSliderTrackShape(),
          trackHeight: 3,
          overlayShape: SliderComponentShape.noOverlay,
          thumbShape: RoundSliderThumbShape(enabledThumbRadius: sliderRadius),
        ),
        child: Slider(
          value: _currentTime!.clamp(0.0, _duration),
          min: 0.0,
          max: _duration,
          onChanged: onSliderChanged,
          onChangeStart: onSliderChangeStart,
          onChangeEnd: onSliderChangeEnd,
          activeColor: Colors.white,
          inactiveColor: Colors.grey,
        ),
      ),
    );
  }

  Widget _keyText() {
    double fadeOutTime = 0.5 * (_deltaHeightPx / _oneSecondPx); // Time in seconds over which text fades out
    double keyTextOpacity = (1 - (_currentTime! / fadeOutTime)).clamp(0.0, 1.0);
    Widget keyText = Positioned(
      left: 2*_deltaWidthPx,
      right: 2*_deltaWidthPx,
      top: _keyTextPx,
      child: Transform.translate(
        offset: Offset(0, min(_currentTimePx, _deltaHeightPx)),
        child: Opacity(
          opacity: keyTextOpacity,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Key: ',
                style: Theme.of(_context!).textTheme.titleLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.normal),
              ),
              const SizedBox(width: 4),
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: onEditMusicalKey,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey[850],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _musicalKey!,
                    style: Theme.of(_context!).textTheme.titleLarge?.copyWith(
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
    return keyText;
  }

  Widget _playButton() {
    double playButtonRadius = 30;
    double playButtonIconSize = 38;
    late Widget playButton;
    if (_isComplete!) {
      playButton = CircleAvatar(
        radius: playButtonRadius,
        backgroundColor: Colors.white,
        child: IconButton(
          icon: const Icon(Icons.replay),
          iconSize: playButtonIconSize,
          color: Colors.black,
          onPressed: onPlayButtonReset,
        ),
      );
    } else {
      playButton = CircleAvatar(
        radius: playButtonRadius,
        backgroundColor: Colors.white,
        child: IconButton(
          icon: Icon(_isPlaying! ? Icons.pause : Icons.play_arrow),
          iconSize: playButtonIconSize,
          color: Colors.black,
          onPressed: onPlayButtonPressed,
        ),
      );
    }
    return Positioned(
      right: 0,
      left: _isPortrait! ? 0 : null, // In portrait mode, center the play button. In landscape mode, align it to the right.
      top: _playButtonPx,
      child: Center(
        child: playButton,
      ),
    );
  }
}