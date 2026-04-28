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
    required double? leftShift, // Shift of chromagram to the left. Range [0.0, 1.0]
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
      _numberOfNotesInScale = _computeNumberOfNotesInScale(tonicIndex, scale);
    }

    _context = context;
    _availableWidthPx =availableWidthPx;
    _availableHeightPx = availableHeightPx;
    _currentTime = currentTime;
    _leftShift = leftShift;
    _isPortrait = isPortrait;
    _isPlaying = isPlaying;
    _isComplete = isComplete;

    // Update derived parameters
    _numSecondsAboveCurrent = _isPortrait ? 5 : 4; // Number of seconds to display above current line
    _numberOfNotesToDisplay = _isPortrait ? 13 : 35; // How many notes to display

    _heightAboveCurrentPx = _isPortrait ? cnst.goldenFactorLarge * _availableHeightPx : 0.7 * _availableHeightPx; // Available height above current line
    _heightBelowCurrentPx = _isPortrait ? cnst.goldenFactorSmall * _availableHeightPx : 0.3 * _availableHeightPx; // Available height below current line

    _oneSecondPx = _heightAboveCurrentPx / _numSecondsAboveCurrent; // One second in pixels
    _durationPx = _duration * _oneSecondPx; // Total duration in pixels
    _currentTimePx = _currentTime * _oneSecondPx; // Current time in pixels

    _currentLinePx = _heightBelowCurrentPx; // Distance of current line from bottom of screen
    _sliderLinePx = _isPortrait ? cnst.goldenFactorLarge * _heightBelowCurrentPx : 0.0; // Distance of slider line from bottom of screen (not used in landscape mode)

    _deltaWidthPx = _availableWidthPx / (2 + _numberOfNotesToDisplay - 1 + 2); // Horizontal offset for vertical lines 
    _deltaHeightPx = _isPortrait ? 0.5 * (_currentLinePx - _sliderLinePx) : 0.5 * _heightBelowCurrentPx; // Vertical offset between current line and bottom line

    _bottomLinePx = _currentLinePx - _deltaHeightPx; // Distance of bottom line from bottom of screen 
    _chromaBlockerPx = _availableHeightPx - _bottomLinePx; // Height of chroma blocker from top of screen

    _playButtonPx = _isPortrait ? (_availableHeightPx - _sliderLinePx) + 0.15 * _sliderLinePx : 0.25 * _deltaWidthPx; // Distance of top of audio player to top of screen
    _timeDisplayPx = _isPortrait ? (_availableHeightPx - _sliderLinePx) + 0.05 * _sliderLinePx : 0.0; // Distance of top of time display to top of screen (not used in landscape mode)

    _deltaHeightOctaveBarPx = _isPortrait ? 0.0 : 0.7 * _heightBelowCurrentPx; // Vertical offset between current line and octave bars

    _pitchLabelPx = (_availableHeightPx - _currentLinePx); // Distance of top of pitch labels from bottom of screen
    _keyTextPx = _isPortrait ? (_availableHeightPx - _currentLinePx) + 0.3 * (_currentLinePx - _sliderLinePx) : (_availableHeightPx - _currentLinePx) + 0.35 * _currentLinePx; // Distance of key text from top of screen
    
    _leftShiftToPx =  ((_isPortrait ? _numberOfNotesInScale : _numBins) - _numberOfNotesToDisplay) * _deltaWidthPx; // Maximum horizontal shift in pixels (when leftShift = 1.0)
    _leftShiftPx = (leftShift != null) ? leftShift * _leftShiftToPx : _computeLeftShiftPx(); // Horizontal shift to the left (based on leftShift)

    List<Widget> chromagramWidgets = [];
    chromagramWidgets.addAll(_pitchIntensityBars());
    chromagramWidgets.addAll(_verticalPitchLines());

    chromagramWidgets.addAll(_bottomLine());
    chromagramWidgets.addAll(_topLine());

    chromagramWidgets.add(_keyText());

    chromagramWidgets.add(_chromaBlocker());

    chromagramWidgets.addAll(_pitchLabels());
    chromagramWidgets.addAll(_octaveBars());

    chromagramWidgets.addAll(_currentLine());

    chromagramWidgets.add(_timeDisplay());
    chromagramWidgets.add(_slider());
    chromagramWidgets.add(_playButton());

    return chromagramWidgets;
  }

  // Current parameters
  late BuildContext _context;
  late double _availableWidthPx;
  late double _availableHeightPx;
  late double _currentTime;
  late double? _leftShift;
  late bool _isPortrait;
  late bool _isPlaying;
  late bool _isComplete;
  String? _musicalKey;
  late int _tonicIndex;
  late String _scale;

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

  late double _deltaHeightOctaveBarPx; // Distance of octave bars from bottom of screen

  late double _pitchLabelPx; // Distance of top of labels from bottom of screen
  late double _keyTextPx; // Distance of key text from top of screen

  late double _leftShiftToPx; // Maximum left shift in pixels (when leftShift is 1.0)
  late double _leftShiftPx; // Current left shift in pixels

  int _computeNumberOfNotesInScale(int tonicIndex, String scale) {
    final scalePattern = cnst.scalePatterns[scale];
    int count = 0;
    for (int i = 0; i < _numBins; i++) {
      final isInScale = scalePattern != null && scalePattern[(i - tonicIndex) % cnst.numPitches] == 1;
      if (isInScale) count++;
    }
    return count;
  }

  double _computeLeftShiftPx() {
    if (!_isPortrait) {
      double leftShiftPx = _tonicIndex * _deltaWidthPx; // In landscape, shift so that tonic (C3 - B3) is the left most note
      _leftShift = leftShiftPx / _leftShiftToPx; // Update leftShift based on leftShiftPx
      return leftShiftPx; 
    }
    // In portrait, shift so that tonic in range (C3 - B3) is the left most note
    double leftShiftPx = 0.0;
    final scalePattern = cnst.scalePatterns[_scale];
    for (int i = 0; i < _numBins; i++) {
      if (i == _tonicIndex + 12) break; // Index at tonic in range (C3 - B3)
      final bool isInScale = scalePattern != null && scalePattern[(i - _tonicIndex) % cnst.numPitches] == 1;
      if (isInScale) {
        leftShiftPx += _deltaWidthPx; // Increase leftShiftPx for each note in scale until we reach the tonic in range (C3 - B3)
      }
    }
    leftShiftPx -= 0.5 * _deltaWidthPx;
    _leftShift = leftShiftPx / _leftShiftToPx; // Update leftShift based on leftShiftPx
    return leftShiftPx;
  }

  double getOneSecondPx() {
    return _oneSecondPx;
  }

  double getLeftShiftToPx() {
    return _leftShiftToPx;
  }

  double getLeftShift() {
    return _leftShift ?? 0.0;
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
    int startIndex = max(0, ((_currentTime - deltaHeightSeconds) / _duration * _numFrames).ceil() - safetyMarginFrames); // Index of first frame to display, with safety margin
    int endIndex = min(_numFrames, ((_currentTime + heightAboveCurrentSeconds) / _duration * _numFrames).floor() + safetyMarginFrames); // Index of last frame to display, with safety margin

    int currentNumberOfPitchBars = 0; // Counter needed for only displaying notes within scale (in portrait mode)
    double pitchBarWidthPx = 0.5 * _deltaWidthPx; // Width of each pitch intensity bar in pixels
    final scalePattern = cnst.scalePatterns[_scale];
    for (int i = 0; i < _numBins; i++) {
      final isInScale = scalePattern != null && scalePattern[(i - _tonicIndex) % cnst.numPitches] == 1; // Determine if pitch class is in scale
      if (_isPortrait && !isInScale) continue; // In portrait mode, only show pitch classes in the scale to reduce clutter
      currentNumberOfPitchBars++;
      double centerOfPitchBarPx = (currentNumberOfPitchBars + 1) * _deltaWidthPx - _leftShiftPx; // Center of pitch bar in pixels
      if (centerOfPitchBarPx < 0 || centerOfPitchBarPx > _availableWidthPx) {
        continue; // Skip drawing pitch bars that are completely outside of the visual window
      }
      double opacityOfPitchBar = 1.0; // Fade out pitch bar at boundary 
      if (centerOfPitchBarPx < 2 * _deltaWidthPx) {
        opacityOfPitchBar = ((centerOfPitchBarPx - _deltaWidthPx) / _deltaWidthPx).clamp(0.0, 1.0);
      } else if (centerOfPitchBarPx > (_availableWidthPx - 2 * _deltaWidthPx)) {
        opacityOfPitchBar = ((_availableWidthPx - _deltaWidthPx - centerOfPitchBarPx) / _deltaWidthPx).clamp(0.0, 1.0);
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
    double topOfVerticalPitchLinePx = (_availableHeightPx - _currentLinePx) - (_durationPx - _currentTimePx);
    int currentNumberOfNotes = 0;
    final scalePattern = cnst.scalePatterns[_scale];
    for (int i = 0; i < _numBins; i++) {
      final isInScale = scalePattern != null && scalePattern[(i - _tonicIndex) % cnst.numPitches] == 1; // Determine if pitch class is in scale
      if (_isPortrait && !isInScale) continue; // In portrait mode, only show pitch classes in the scale to reduce clutter
      currentNumberOfNotes++;
      double centerOfVerticalPitchLinePx = (currentNumberOfNotes + 1) * _deltaWidthPx - _leftShiftPx;
      if (centerOfVerticalPitchLinePx < _deltaWidthPx || centerOfVerticalPitchLinePx > (_availableWidthPx - _deltaWidthPx)) {
        continue; // Skip drawing vertical lines that are completely outside of the visual window
      }
      final Color lineColor = isInScale ? Colors.grey[400]! : Colors.grey[900]!;
      verticalPitchLines.add(_verticalLineWithFadeOutBoundary(
        startPx: _currentLinePx - min(_currentTimePx, _deltaHeightPx),
        endPx: _availableHeightPx - max(topOfVerticalPitchLinePx, 0),
        leftPx: centerOfVerticalPitchLinePx,
        color: lineColor,
      ));
    }
    return verticalPitchLines;
  }

  // Horizontal line at the end (top) of the chromagram, with fade-out at screen boundaries
  List<Widget> _topLine() {
    final double startPx = 2 * _deltaWidthPx - _leftShiftPx;
    final double endPx = startPx + ((_isPortrait ? _numberOfNotesInScale : _numBins) - 1) * _deltaWidthPx;
    return _horizontalLineWithFadeOutBoundary(
      startPx: startPx,
      endPx: endPx + 1, // +1 to align the lines at the top right corner perfectly
      bottomPx: _currentLinePx + _durationPx,
      offsetPx: _currentTimePx,
      color: Colors.grey,
    );
  }

  // Horizontal line at the start (bottom) of the chromagram, with fade-out at screen boundaries
  List<Widget> _bottomLine() {
    final double startPx = 2 * _deltaWidthPx - _leftShiftPx;
    final double endPx = startPx + ((_isPortrait ? _numberOfNotesInScale : _numBins) - 1) * _deltaWidthPx;
    return _horizontalLineWithFadeOutBoundary(
      startPx: startPx,
      endPx: endPx,
      bottomPx: _currentLinePx,
      offsetPx: min(_currentTimePx, _deltaHeightPx),
      color: Colors.grey,
    );
  }

  // Horizontal line for the start and end of the chromagram
  Widget _horizontalLine({required String position}) {
    late double bottomPx;
    late double offsetPx;
    double leftPx = 2 * _deltaWidthPx - _leftShiftPx;
    double rightPx = _availableWidthPx - (2 * _deltaWidthPx - _leftShiftPx + ((_isPortrait ? _numberOfNotesInScale : _numBins) - 1) * _deltaWidthPx);
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
      right: max(rightPx, 2 * _deltaWidthPx) - 1, // -1 to align the lines at the top right corner perfectly
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

  List<Widget> _octaveBars() {
    int leftBinIndex = 36;
    int rightBinIndex = 47;
    int octaveNumber = 2;
    List<Widget> octaveBars = [];

    octaveBars.addAll(_octaveBar(leftBinIndex: leftBinIndex, rightBinIndex: rightBinIndex, octaveNumber: octaveNumber));
    return octaveBars;
  }

  List<Widget> _octaveBar({required int leftBinIndex, required int rightBinIndex, required int octaveNumber}) {
    List<Widget> octaveBar = [];

    double bottomPx = _currentLinePx - (_deltaHeightOctaveBarPx - _deltaHeightPx); // Initial bottom position of octave bars (currentTimePx = 0)
    double offsetPx = min(_currentTimePx, _deltaHeightPx); // Vertical offset, depending on currentTimePx, capped at _deltaHeightPx

    double startPx = 2 * _deltaWidthPx + leftBinIndex * _deltaWidthPx - _leftShiftPx; // Start position of octave bars (distance from left edge of screen)
    double endPx = 2 * _deltaWidthPx + rightBinIndex * _deltaWidthPx - _leftShiftPx; // End position of octave bars (distance from left edge of screen)

    double leftBoundaryStartPx = min(max(startPx, _deltaWidthPx), 2 * _deltaWidthPx); // Start of left boundary, where octave bars start to fade in
    double leftBoundaryEndPx = min(2 * _deltaWidthPx, endPx); // End of left boundary, where octave bars are fully visible

    double middleStartPx = max(2 * _deltaWidthPx, startPx); // Start of middle section
    double middleEndPx = min(_availableWidthPx - 2 * _deltaWidthPx, endPx); // End of middle section

    double rightBoundaryStartPx = max(_availableWidthPx - 2 * _deltaWidthPx, startPx); // Start of right boundary, where octave bars start to fade out
    double rightBoundaryEndPx = _availableWidthPx - min(max(_availableWidthPx - endPx, _deltaWidthPx), 2 * _deltaWidthPx); // End of right boundary, where octave bars end to fade out

    // Calculate the center and gap width for the middle segment
    double centerPx = (startPx + endPx) / 2;
    double gapWidthPx = 32; // Width of the gap for the octave number
    double middleLeftEndPx = centerPx - gapWidthPx / 2;
    double middleRightStartPx = centerPx + gapWidthPx / 2;

    // Left boundary
    Widget octaveBarLeft = Positioned(
      left: leftBoundaryStartPx,
      right: _availableWidthPx - leftBoundaryEndPx,
      bottom: bottomPx,
      child: Transform.translate(
        offset: Offset(0, offsetPx),
        child: Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.orange.withValues(alpha: 0.25),
                Colors.orange,
              ],
            ),
          ),
        ),
      ),
    );
    octaveBar.add(octaveBarLeft);

    // Right boundary
    Widget octaveBarRight = Positioned(
      left: rightBoundaryStartPx,
      right: _availableWidthPx - rightBoundaryEndPx,
      bottom: bottomPx,
      child: Transform.translate(
        offset: Offset(0, offsetPx),
        child: Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: [
                Colors.orange.withValues(alpha: 0.25),
                Colors.orange,
              ],
            ),
          ),
        ),
      ),
    );
    octaveBar.add(octaveBarRight);

    // Middle left segment (before gap)
    if (middleLeftEndPx > middleStartPx) {
      Widget octaveBarMiddleLeft = Positioned(
        left: middleStartPx,
        right: _availableWidthPx - middleLeftEndPx,
        bottom: bottomPx,
        child: Transform.translate(
          offset: Offset(0, offsetPx),
          child: Container(
            height: 1,
            color: Colors.white,
          ),
        ),
      );
      octaveBar.add(octaveBarMiddleLeft);
    }

    // Middle right segment (after gap)
    if (middleRightStartPx < middleEndPx) {
      Widget octaveBarMiddleRight = Positioned(
        left: middleRightStartPx,
        right: _availableWidthPx - middleEndPx,
        bottom: bottomPx,
        child: Transform.translate(
          offset: Offset(0, offsetPx),
          child: Container(
            height: 1,
            color: Colors.white,
          ),
        ),
      );
      octaveBar.add(octaveBarMiddleRight);
    }


    // Octave number in the gap, styled and faded like notes in the scale
    double opacityOfOctaveNumber = 1.0;
    double centerOfOctaveNumberPx = centerPx;
    // Fade out at boundaries, similar to _pitchLabels
    if (centerOfOctaveNumberPx < 2 * _deltaWidthPx) {
      opacityOfOctaveNumber = ((centerOfOctaveNumberPx - _deltaWidthPx) / _deltaWidthPx).clamp(0.0, 1.0);
    } else if (centerOfOctaveNumberPx > (_availableWidthPx - 2 * _deltaWidthPx)) {
      opacityOfOctaveNumber = ((_availableWidthPx - _deltaWidthPx - centerOfOctaveNumberPx) / _deltaWidthPx).clamp(0.0, 1.0);
    }

    const double textHeight = 14.0;
    Widget octaveNumberWidget = Positioned(
      left: centerPx - gapWidthPx / 2,
      width: gapWidthPx,
      bottom: bottomPx - textHeight / 4, // Center text vertically on the horizontal line
      child: Transform.translate(
        offset: Offset(0, offsetPx),
        child: SizedBox(
          height: textHeight,
          child: Center(
            child: Text(
              octaveNumber.toString(),
              style: TextStyle(
                color: Colors.grey[200]!.withValues(alpha: opacityOfOctaveNumber),
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
    octaveBar.add(octaveNumberWidget);

    return octaveBar;
  }


  // Horizontal line from startPx to endPx (relative to left edge of screen), at bottomPx from the bottom.
  // Fades out at the screen boundaries (between _deltaWidthPx and 2*_deltaWidthPx on each side).
  // offsetPx is applied as a vertical Transform.translate for animation.
  List<Widget> _horizontalLineWithFadeOutBoundary({
    required double startPx,
    required double endPx,
    required double bottomPx,
    double offsetPx = 0.0,
    Color color = Colors.grey,
  }) {
    List<Widget> widgets = [];

    // Left fade zone: startPx.._deltaWidthPx -> 2*_deltaWidthPx, transparent to opaque
    final double leftFadeStart = max(startPx, _deltaWidthPx);
    final double leftFadeEnd = min(2 * _deltaWidthPx, endPx);
    if (leftFadeEnd > leftFadeStart) {
      widgets.add(Positioned(
        left: leftFadeStart,
        right: _availableWidthPx - leftFadeEnd,
        bottom: bottomPx,
        child: Transform.translate(
          offset: Offset(0, offsetPx),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [color.withValues(alpha: 0.25), color],
              ),
            ),
          ),
        ),
      ));
    }

    // Middle solid zone
    final double middleStart = max(2 * _deltaWidthPx, startPx);
    final double middleEnd = min(_availableWidthPx - 2 * _deltaWidthPx, endPx);
    if (middleEnd > middleStart) {
      widgets.add(Positioned(
        left: middleStart,
        right: _availableWidthPx - middleEnd,
        bottom: bottomPx,
        child: Transform.translate(
          offset: Offset(0, offsetPx),
          child: Container(height: 1, color: color),
        ),
      ));
    }

    // Right fade zone: _availableWidthPx-2*_deltaWidthPx -> _availableWidthPx-_deltaWidthPx, opaque to transparent
    final double rightFadeStart = max(_availableWidthPx - 2 * _deltaWidthPx, startPx);
    final double rightFadeEnd = min(_availableWidthPx - _deltaWidthPx, endPx);
    if (rightFadeEnd > rightFadeStart) {
      widgets.add(Positioned(
        left: rightFadeStart,
        right: _availableWidthPx - rightFadeEnd,
        bottom: bottomPx,
        child: Transform.translate(
          offset: Offset(0, offsetPx),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [color, color.withValues(alpha: 0.25)],
              ),
            ),
          ),
        ),
      ));
    }

    return widgets;
  }

  // Vertical line from startPx to endPx (relative to bottom of screen), at leftPx from the left.
  // The line fades out as a whole when leftPx is near the screen's left or right boundary
  // (between _deltaWidthPx and 2*_deltaWidthPx on each side), matching vertical pitch line behavior.
  // offsetPx is applied as a vertical Transform.translate for animation.
  Widget _verticalLineWithFadeOutBoundary({
    required double startPx,
    required double endPx,
    required double leftPx,
    double offsetPx = 0.0,
    Color color = Colors.grey,
  }) {
    double opacity = 1.0;
    if (leftPx < 2 * _deltaWidthPx) {
      opacity = ((leftPx - _deltaWidthPx) / _deltaWidthPx).clamp(0.0, 1.0);
    } else if (leftPx > (_availableWidthPx - 2 * _deltaWidthPx)) {
      opacity = ((_availableWidthPx - _deltaWidthPx - leftPx) / _deltaWidthPx).clamp(0.0, 1.0);
    }

    return Positioned(
      left: leftPx,
      width: 1,
      bottom: startPx,
      top: _availableHeightPx - endPx,
      child: Transform.translate(
        offset: Offset(0, offsetPx),
        child: Opacity(
          opacity: opacity,
          child: Container(width: 1, color: color),
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

  // Note labels below the chromagram, aligned with vertical pitch lines
  List<Widget> _pitchLabels() {
    List<Widget> pitchLabels = [];
    int currentNumberOfPitchLabels = 0;
    final scalePattern = cnst.scalePatterns[_scale]; // Scale pattern of current musical key 
    final noteNames = cnst.noteNames[_scale]![_tonicIndex]!; // Note names for current musical key
    for (int i = 0; i < _numBins; i++) {
      final int octaveNumber = (i / cnst.numPitches).floor() + 2; // Octave number based on index (C2 starts at index 0)
      final int pitchClassIndex = i % cnst.numPitches; // Pitch class index (0-11)
      final bool isInScale = scalePattern != null && scalePattern[(i - _tonicIndex) % cnst.numPitches] == 1; // Determine if note is in scale
      final bool isTonic = (i - _tonicIndex) % cnst.numPitches == 0; // Determine if note is tonic
      final String absoluteNoteName = noteNames[pitchClassIndex] + octaveNumber.toString(); // Absolute note name (e.g., C4, G#3)]

      if (_isPortrait && !isInScale) continue; // In portrait mode, only show pitch classes in the scale to reduce clutter
      currentNumberOfPitchLabels++;

      double centerOfPitchLabelPx = (currentNumberOfPitchLabels + 1) * _deltaWidthPx - _leftShiftPx; // Where to put the label horizontally
      if (centerOfPitchLabelPx < _deltaWidthPx || centerOfPitchLabelPx > (_availableWidthPx - _deltaWidthPx)) {
        continue; // Skip drawing pitch labels that are completely outside of the visual window
      }

      double opacityOfPitchLabel = 1.0; // Opacity fades out at boundary
      if (centerOfPitchLabelPx < 2 * _deltaWidthPx) {
        opacityOfPitchLabel = ((centerOfPitchLabelPx - _deltaWidthPx) / _deltaWidthPx).clamp(0.0, 1.0);
      } else if (centerOfPitchLabelPx > (_availableWidthPx - 2 * _deltaWidthPx)) {
        opacityOfPitchLabel = ((_availableWidthPx - _deltaWidthPx - centerOfPitchLabelPx) / _deltaWidthPx).clamp(0.0, 1.0);
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
                absoluteNoteName,
                style: TextStyle(
                  color: isInScale && isTonic ? Colors.white.withValues(alpha: opacityOfPitchLabel) : 
                         isInScale ? Colors.grey[200]!.withValues(alpha: opacityOfPitchLabel) : 
                         Colors.grey[700]!.withValues(alpha: opacityOfPitchLabel),
                  fontSize: 12,
                  fontWeight: isTonic ? FontWeight.w900 : FontWeight.w400,
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

  List<Widget> _currentLine() {
    double iconSize = 30;
    return [
      Positioned(
        // Align the center of the line with currentLinePx
        bottom: _currentLinePx,
        left: _deltaWidthPx,
        right: _deltaWidthPx,
        child: Container(
          height: 1,
          color: Colors.white,
        ),
      ),
      Positioned(
        bottom: _currentLinePx - iconSize / 2 + 0.5, // +0.5 shift to center (experimentally determined)
        left: _deltaWidthPx - iconSize / 2,
        child: Icon(
          Icons.play_arrow,
          color: Colors.white,
          size: iconSize,
        ),
      ),
    ];
  }

  // Widget to display current time and total duration aligned with slider ends
  Widget _timeDisplay() {
    if (!_isPortrait) return SizedBox.shrink(); // Only show time display in portrait mode
    return Positioned(
      left: _deltaWidthPx,
      right: _deltaWidthPx,
      top: _timeDisplayPx,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            conv.formatTime(_currentTime),
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
    if (!_isPortrait) return SizedBox.shrink(); // Only show slider in portrait mode
    double sliderRadius = 8; 
    return Positioned(
        left: _deltaWidthPx - sliderRadius,
        right: _deltaWidthPx - sliderRadius,
        bottom: _sliderLinePx - sliderRadius,
        child: SliderTheme(
        data: SliderTheme.of(_context).copyWith(
          trackShape: const RoundedRectSliderTrackShape(),
          trackHeight: 3,
          overlayShape: SliderComponentShape.noOverlay,
          thumbShape: RoundSliderThumbShape(enabledThumbRadius: sliderRadius),
        ),
        child: Slider(
          value: _currentTime.clamp(0.0, _duration),
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

    final noteNames = cnst.noteNames[_scale]![_tonicIndex]!; // Note names for current musical key
    final String musicalKey = noteNames[_tonicIndex]! + ' ' + _scale; // Musical key (e.g., "C major")
    double fadeOutTime = 0.5 * (_deltaHeightPx / _oneSecondPx); // Time in seconds over which text fades out
    double keyTextOpacity = (1 - (_currentTime / fadeOutTime)).clamp(0.0, 1.0);
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
                style: Theme.of(_context).textTheme.titleLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.normal),
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
                    musicalKey,
                    style: Theme.of(_context).textTheme.titleLarge?.copyWith(
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
    if (_isComplete) {
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
          icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
          iconSize: playButtonIconSize,
          color: Colors.black,
          onPressed: onPlayButtonPressed,
        ),
      );
    }
    return Positioned( // In portrait, center play button towards bottom of screen. In landscape, align it to the top right corner
      right: _isPortrait ? 0 : 0.25 * _deltaWidthPx,
      left: _isPortrait ? 0 : null, 
      top: _playButtonPx,
      child: Center(
        child: playButton,
      ),
    );
  }
}