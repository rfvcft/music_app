import 'package:flutter/material.dart';

// COLORS
const List<Color> infernoColors = [ // Sampled inferno colormap (10 samples)
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

// GOLDEN RATIO
const double goldenRatio = 1.6180339887; // Golden ratio = (1 + sqrt(5)) / 2
const double goldenFactorSmall = 1 / (goldenRatio + 1); // Smaller golden section
const double goldenFactorLarge = goldenRatio / (goldenRatio + 1); // Larger golden section

// PITCH CLASSES
const int numPitches = 12; // Number of pitch classes
const List<String> pitchClassNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']; // Pitch class names from C to B
const List<int> pitchClassIndices = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]; // Pitch class indices from 0 to 11
const Map<String, int> pitchClassNameToIndex = { 
  'C': 0,
  'C#': 1,
  'D': 2,
  'D#': 3,
  'E': 4,
  'F': 5,
  'F#': 6,
  'G': 7,
  'G#': 8,
  'A': 9,
  'A#': 10,
  'B': 11,
}; // Map from pitch class names to indices
const Map<int, String> pitchClassIndexToName = { 
  0: 'C',
  1: 'C#',
  2: 'D',
  3: 'D#',
  4: 'E',
  5: 'F',
  6: 'F#',
  7: 'G',
  8: 'G#',
  9: 'A',
  10: 'A#',
  11: 'B',
}; // Map from pitch class indices to names

// ABSOLUTE NOTES 
const List<String> absoluteNoteNames = ['C2', 'C#2', 'D2', 'D#2', 'E2', 'F2', 'F#2', 'G2', 'G#2', 'A2', 'A#2', 'B2',
  'C3', 'C#3', 'D3', 'D#3', 'E3', 'F3', 'F#3', 'G3', 'G#3', 'A3', 'A#3', 'B3',
  'C4', 'C#4', 'D4', 'D#4', 'E4', 'F4', 'F#4', 'G4', 'G#4', 'A4', 'A#4', 'B4',
  'C5', 'C#5', 'D5', 'D#5', 'E5', 'F5', 'F#5', 'G5', 'G#5', 'A5', 'A#5', 'B5',
  'C6']; // Note names for 49 bins from C2 to C6

// SCALES 
const List<String> scaleDegrees = ['1', '♭2', '2', '♭3', '3', '4', '♯4', '5', '♭6', '6', '♭7', '7']; // Scale degree names

const List<int> majorScale = [1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1]; // Major scale pattern
const List<int> minorScale = [1, 0, 1, 1, 0, 1, 0, 1, 1, 0, 1, 0]; // Minor scale pattern
const Map<String, List<int>> scalePatterns = {
  'major': majorScale,
  'minor': minorScale,
};

