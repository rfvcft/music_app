#pragma once
#include <vector>
#include <algorithm>
#include <cmath>

// Enhance chromagram by converting to log scale, dropping low amplitudes, applying median time filter and removing short excitations
class ChromaEnhancer {
public:
    ChromaEnhancer(
        const std::vector<std::vector<float>>& chromaMatrix, // Input: chroma matrix (frames x pitch classes)
        std::vector<std::vector<float>>& enhancedChromaMatrix, // Output: enhanced chroma matrix
        int sampleRate, // Sample rate in Hz (needed to convert median filter window size and minimum duration from seconds to frames)
        int hopSize, // Hop size in samples (needed to convert median filter window size and minimum duration from seconds to frames)
        float localMaxWindowSizeInSeconds, // Parameter: window size for local maximum in seconds (0 to use global maximum) (Default: 2.0)
        float lowAmplitudeThreshold, // Parameter: Relative threshold for dropping low amplitudes (0.0 = no drop, 1.0 = drop all). (Default: 0.90)
        float medianLengthInSeconds, // Parameter: Window size for median filtering in seconds (0 to bypass this) (Default: ?)
        float minDurationInSeconds, // Parameter: Minimum duration for a chroma excitation to be kept in seconds (0 to bypass this) (Default: ?)
        bool deactive, // Parameter: If true, chroma enhancement is deactivated (chromaMatrix = enhancedChromaMatrix)
        int resolutionFactor = 1 // Parameter: Temporal upsampling factor (1 = no interpolation, 2 = double frames, ...)
    );

    void computeEnhancement();

private:
    const std::vector<std::vector<float>>& chromaMatrix; 
    std::vector<std::vector<float>>& enhancedChromaMatrix; 
    int sampleRate;
    int hopSize;
    float localMaxWindowSizeInSeconds;
    float lowAmplitudeThreshold;
    float medianLengthInSeconds;
    float minDurationInSeconds;
    int resolutionFactor;
    bool deactive;

    int localMaxWindowSizeInFrames; // Window size (in frames) for sliding maximum in time 
    int medianLengthInFrames; // Window size (in frames) for median filtering in time (must be odd)
    int minDurationInFrames; // Minimum duration (in frames) for a chroma excitation to be kept

    float eps = 1e-12f; // small constant to avoid log(0)

    void convertToLogScale();
    void normalizeByLocalMaximaInTime();
    void dropLowAmplitudes(float threshold);
    void dropShortTimeExcitations(int minDurationFrames);
    void medianTimeFilterSliding(int windowSize);
    void interpolateInTime(int factor);
    void normalizeChroma(bool normalize);
};