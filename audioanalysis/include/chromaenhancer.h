#pragma once
#include <vector>
#include <algorithm>
#include <cmath>

// Enhance chroma by converting to log scale and dropping low amplitudes
class ChromaEnhancer {
public:
    ChromaEnhancer(
        const std::vector<std::vector<float>>& inputChroma, // Input: chroma matrix (frames x pitch classes)
        std::vector<std::vector<float>>& outputChroma // Output: enhanced chroma matrix
    );

    // Parameters
    float threshold = 0.88f; // Values below threshold are dropped (on log scale). 1.0 = drop everything, 0.0 = keep everything. 0.82 is a good value
    bool enhanceSmooth = false; // Enhance values using a non-linear smooth function
    bool normalize = false; // normalize each frame with max norm

    void computeEnhancement();

private:
    const std::vector<std::vector<float>>& chromaMatrix; 
    std::vector<std::vector<float>>& enhancedChromaMatrix; 

    void convertToLogScale();
    void dropNoise();
    void enhanceSmoothly();
    float smoothEnhancer(float x);
    void normalizeChromaFrames();
};