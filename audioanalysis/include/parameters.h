#pragma once
#include <string>
#include <vector>

// Parameters for algorithms used in AudioAnalyzer.

// Universal parameters
extern int hopSize;
extern int frameSize;

// FrameCutter parameters
extern std::string frameCutterCurrentPositionAt;

// PercussionRemover parameters
extern float percussionRemoverMedianLengthInSeconds;
extern float percussionRemoverMedianLengthInHertz;
extern float percussionRemoverMinFrequency;
extern float percussionRemoverMaxFrequency;
extern bool percussionRemoverDeactive;

// PeakFinder parameters
extern float peakFinderMinFrequency;
extern float peakFinderMaxFrequency;
extern int peakFinderMaxPeaks;

// ChromaConverter parameters
extern float chromaConverterMinFrequency;
extern float chromaConverterMaxFrequency;
extern int chromaConverterNumBins;
extern bool chromaConverterUseSmoothTransition;
extern std::string chromaConverterOvertoneFilter;

// ChromaEnhancer parameters
extern float chromaEnhancerLocalMaxWindowSizeInSeconds;
extern float chromaEnhancerLowAmplitudeThreshold;
extern float chromaEnhancerMedianLengthInSeconds;
extern float chromaEnhancerMinDurationInSeconds;
extern bool chromaEnhancerDeactive;

// KeyFinder parameters
extern std::vector<float> keyFinderMajorProfile;
extern std::vector<float> keyFinderMinorProfile;
extern int keyFinderMinBin;
extern int keyFinderMaxBin;