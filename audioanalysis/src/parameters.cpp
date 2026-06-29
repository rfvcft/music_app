#include "parameters.h"

// Universal parameters
int hopSize = 2048; // Hop size in samples
int frameSize = 8192; // Frame size in samples. Must be a power of 2 for FFT efficiency.

// FrameCutter parameters
std::string frameCutterCurrentPositionAt = "center"; // "start", "center" or "end"

// PercussionRemover parameters
float percussionRemoverMedianLengthInSeconds = 0.39f; 
float percussionRemoverMedianLengthInHertz = 183.0f;
float percussionRemoverMinFrequency = 0.0f; // Range in which to apply percussion removal (in Hz)
float percussionRemoverMaxFrequency = 4400.0f; 
bool percussionRemoverDeactive = false;

// PeakFinder parameters
float peakFinderMinFrequency = 10.0f; // Range in which we look for peaks (in Hz)
float peakFinderMaxFrequency = 4400.0f; 
int peakFinderMaxPeaks = 30; // Maximum number of peaks to return per frame

// ChromaConverter parameters
float chromaConverterMinFrequency = 50.0f; // Range in which we do computations (in Hz)
float chromaConverterMaxFrequency = 4400.0f;
int chromaConverterNumBins = 72; // 6 octaves, bin 0 corresponds to C1 = MIDI 24
bool chromaConverterUseSmoothTransition = true; // Use a smooth cutoff function at semitone boundaries
std::string chromaConverterOvertoneFilter = "nnls"; // Type of overtone filter to use: "none", "basic", "nnls"

// ChromaEnhancer parameters
float chromaEnhancerLocalMaxWindowSizeInSeconds = 3.0f; // Window size for local maximum in seconds (0 to use global maximum) 
float chromaEnhancerLowAmplitudeThreshold = 0.89f; // Relative threshold for dropping low amplitudes (0.0 = no drop, 1.0 = drop all)
float chromaEnhancerMedianLengthInSeconds = 0.15f; // Window size for median filtering in seconds (0 to bypass this)
float chromaEnhancerMinDurationInSeconds = 0.0f; // Minimum duration for a chroma excitation to be kept in seconds (0 to bypass this)
int chromaEnhancerResolutionFactor = 2; // Temporal upsampling factor (1 = no interpolation)
bool chromaEnhancerDeactive = false; // If true, chroma enhancement is deactivated (chromaMatrix = enhancedChromaMatrix)

// KeyFinder parameters
std::vector<float> keyFinderMajorProfile = { 1.00, 0.00, 0.55, 0.00, 0.85, 0.55, 0.00, 0.90, 0.00, 0.70, 0.00, 0.50 };
std::vector<float> keyFinderMinorProfile = { 1.00, 0.00, 0.55, 0.85, 0.00, 0.55, 0.00, 0.90, 0.70, 0.00, 0.50, 0.00 };
int keyFinderMinBin = 12; // Minimum chroma bin index to consider (-1 to bypass)
int keyFinderMaxBin = 72; // Maximum chroma bin index to consider, exclusive (-1 to bypass)
