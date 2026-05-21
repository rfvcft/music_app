#pragma once
#include <string>

// Parameters for algorithms used in AudioAnalyzer.

// Universal parameters
int hopSize = 1024; // Hop size in samples
int frameSize = 8192; // Frame size in samples. Must be a power of 2 for FFT efficiency.
// Note: The sampleRate is explicitly passed to the AudioAnalyzer constructor

// FrameCutter parameters
std::string frameCutterCurrentPositionAt = "center"; // "start", "center" or "end" - defines whether current position refers to start, center of end of frame.

// PercussionRemover parameters
float percussionRemoverMedianLengthInSeconds = 0.39f; // Length of median filter in seconds.
float percussionRemoverMedianLengthInHertz = 183.0f; // Length of median filter in Hz.
float percussionRemoverMinFrequency = 0.0f; // Minimum frequency to consider, in Hz (the frequency range must be larger than the frequency range in PeakFinder)
float percussionRemoverMaxFrequency = 4400.0f; // Maximum frequency to consider, in Hz (the frequency range must be larger than the frequency range in PeakFinder)
bool percussionRemoverDeactive = false; // If true, percussion removal is deactivated (output = input)

// PeakFinder parameters
float peakFinderMinFrequency = 40.0f; // Minimum frequency to consider, in Hz
float peakFinderMaxFrequency = 4200.0f; // Maximum frequency to consider, in Hz
int peakFinderMaxPeaks = 30; // Maximum number of peaks to detect

// ChromaConverter parameters
float chromaConverterMinFrequency = 40.0f; // Minimum frequency to consider, in Hz
float chromaConverterMaxFrequency = 4200.0f; // Maximum frequency to consider, in Hz
int chromaConverterNumBins = 48; // Number of chroma bins (bin 0 corresponds to C2 = MIDI 36)
bool chromaConverterUseSmoothTransition = true; // Use smooth transition at semitone boundaries
std::string chromaConverterOvertoneFilter = "nnls"; // What type of overtone filter we want to use. ("none", "basic", "nnls")

// ChromaEnhancer parameters
float chromaEnhancerLocalMaxWindowSizeInSeconds = 4.0f; // Window size for local maximum in seconds (0 to use global maximum)
float chromaEnhancerLowAmplitudeThreshold = 0.86f; // Relative threshold for dropping low amplitudes (0.0 = no drop, 1.0 = drop all)
float chromaEnhancerMedianLengthInSeconds = 0.1f; // Window size for median filtering in seconds (0 to bypass this)
float chromaEnhancerMinDurationInSeconds = 0.1f; // Minimum duration (in seconds) for a chroma excitation to be kept (0 to bypass this)
bool chromaEnhancerDeactive = false; // If true, chroma enhancement is deactivated (output = input)

// KeyFinder parameters
std::vector<float> keyFinderMajorProfile = { 1.00, 0.00, 0.55, 0.00, 0.85, 0.55, 0.00, 0.90, 0.00, 0.70, 0.00, 0.50 }; // Recommended by ChatGPT
std::vector<float> keyFinderMinorProfile = { 1.00, 0.00, 0.55, 0.85, 0.00, 0.55, 0.00, 0.90, 0.70, 0.00, 0.50, 0.00 }; // Recommended by ChatGPT