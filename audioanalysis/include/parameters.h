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
bool chromaConverterOctaveReduced = false; // If true, output chroma vector will be octave reduced and numBins will be set to 12. If false, numBins chroma bins will be output, where bin 0 corresponds to C2 = MIDI 36.
int chromaConverterNumBins = 49; // Number of chroma bins (bin 0 corresponds to C2 = MIDI 36)
bool chromaConverterUseSmoothTransition = true; // Use smooth transition at semitone boundaries
std::string chromaConverterOvertoneFilter = "basic"; // What type of overtone filter we want to use. ("none", "basic", "nnls")

// ChromaEnhancer parameters
float chromaEnhancerLocalMaxWindowSizeInSeconds = 4.0f; // Window size for local maximum in seconds (0 to use global maximum)
float chromaEnhancerLowAmplitudeThreshold = 0.89f; // Relative threshold for dropping low amplitudes (0.0 = no drop, 1.0 = drop all)
float chromaEnhancerMedianLengthInSeconds = 0.1f; // Window size for median filtering in seconds (0 to bypass this)
float chromaEnhancerMinDurationInSeconds = 0.1f; // Minimum duration (in seconds) for a chroma excitation to be kept (0 to bypass this)

// KeyFinder parameters
//std::vector<float> keyFinderMajorProfile = { 1.00, 0.00, 0.42, 0.00, 0.53, 0.37, 0.00, 0.77, 0.00, 0.38, 0.21, 0.30 }; // bgate (used by Essentia, not useful for us)
//std::vector<float> keyFinderMinorProfile = { 1.00, 0.00, 0.36, 0.39, 0.00, 0.38, 0.00, 0.74, 0.27, 0.00, 0.42, 0.23 }; // bgate (used by Essentia, not useful for us)
//std::vector<float> keyFinderMajorProfile = { 1.0000, 0.1573, 0.4200, 0.1570, 0.5296, 0.3669, 0.1632, 0.7711, 0.1676, 0.3827, 0.2113, 0.2965 }; // braw (used by Essentia, not useful for us)
//std::vector<float> keyFinderMinorProfile = { 1.0000, 0.2330, 0.3615, 0.3905, 0.2925, 0.3777, 0.1961, 0.7425, 0.2701, 0.2161, 0.4228, 0.2272 }; // braw (used by Essentia, not useful for us)
std::vector<float> keyFinderMajorProfile = { 1.00, 0.00, 0.55, 0.00, 0.85, 0.55, 0.00, 0.90, 0.00, 0.70, 0.00, 0.50 }; // Recommended by ChatGPT
std::vector<float> keyFinderMinorProfile = { 1.00, 0.00, 0.55, 0.85, 0.00, 0.55, 0.00, 0.90, 0.70, 0.00, 0.50, 0.00 }; // Recommended by ChatGPT