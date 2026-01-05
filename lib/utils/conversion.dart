import 'package:flutter/material.dart';
import 'constants.dart' as cnst;

// Convert a normalized intensity (0.0 to 1.0) to a color using the inferno colormap
Color infernoColormap(double intensity) {
  intensity = intensity.clamp(0.0, 1.0);

  final scaled = intensity * (cnst.infernoColors.length - 1);
  final idx = scaled.floor();
  final frac = scaled - idx;

  if (idx >= cnst.infernoColors.length - 1) {
    return cnst.infernoColors.last;
  }
  return Color.lerp(cnst.infernoColors[idx], cnst.infernoColors[idx + 1], frac)!;
}

// Format time in seconds to "MM:SS" string
String formatTime(double seconds) {
    final int min = seconds ~/ 60;
    final int sec = seconds.toInt() % 60;
    // Only show leading zero for minutes if time is 10 minutes or more
    if (min < 10) {
      return '$min:${sec.toString().padLeft(2, '0')}';
    } else {
      return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
    }
  }


// Convert musical key in String format (e.g. "C major") to tonic index and mode (e.g. (0, "major"))
(int, String) parseMusicalKey(String key) {
  // Supported tonic pitch classes: C, C#, D, D#, E, F, F#, G, G#, A, A#, B
  // Supported modes: major, minor
    final RegExp regex = RegExp(r'^(C#?|D#?|E|F#?|G#?|A#?|B)\s+(major|minor)$', caseSensitive: false);
  final match = regex.firstMatch(key.trim());
  if (match == null) {
    throw FormatException('Invalid key format: $key');
  }
  final tonic = match.group(1)!.toUpperCase();
  final mode = match.group(2)!.toLowerCase();
  final tonicIndex = cnst.pitchClassNameToIndex[tonic] ?? -1;
  if (tonicIndex == -1) {
    throw FormatException('Unknown tonic: $tonic');
  }
  return (tonicIndex, mode);
}
