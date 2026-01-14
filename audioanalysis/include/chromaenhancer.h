#pragma once
#include <vector>
#include <algorithm>
#include <cmath>

// Enhance chromagram by converting to log scale, dropping low amplitudes, applying median time filter and removing short excitations
class ChromaEnhancer {
public:
    ChromaEnhancer(
        const std::vector<std::vector<float>>& inputChroma, // Input: chroma matrix (frames x pitch classes)
        std::vector<std::vector<float>>& outputChroma // Output: enhanced chroma matrix
    );

    // Parameters
    float lowAmplitudeThreshold = 0.90f; // Relative threshold for dropping low amplitudes (0.0 = no drop, 1.0 = drop all). 0.90f is a good default
    int medianFilterWindowSize = 7; // Window size for median filtering in time (must be odd). (0 to bypass this.) 7 is a good default
    int minDuration = 10; // Minimum duration (in frames) for a chroma excitation to be kept (0 to bypass this.) 10 is a good default
    bool normalize = false; // If true normalize each chroma vector using the max norm. Should be set to false (option only for testing)
    
    void computeEnhancement();

private:
    const std::vector<std::vector<float>>& chromaMatrix; 
    std::vector<std::vector<float>>& enhancedChromaMatrix; 

    void convertToLogScale();
    void dropLowAmplitudes(float threshold);
    void dropShortTimeExcitations(int minDurationFrames);
    void medianTimeFilterSliding(int windowSize);
    void normalizeChroma(bool normalize);
};