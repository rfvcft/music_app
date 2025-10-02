#include "chromaconverter.h"
#include <algorithm>
#include <cmath>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

ChromaConverter::ChromaConverter(const std::vector<float>& peakMagBuffer,
                                 const std::vector<float>& peakFreqBuffer,
                                 std::vector<float>& chromaBuffer): 
    peakMagnitudes(peakMagBuffer), 
    peakFrequencies(peakFreqBuffer), 
    chroma(chromaBuffer) { chroma.resize(numBins, 0.0f); } 

void ChromaConverter::computeChroma() {
    std::fill(chroma.begin(), chroma.end(), 0.0f);

    for (size_t i = 0; i < peakFrequencies.size(); ++i) {
        float freq = peakFrequencies[i];
        if (freq < minFrequency || freq > maxFrequency) continue;

        // Compute pitch class 
        float unroundedSemitone = 12.0f * std::log2(freq / referenceFrequency) + referencePitchClass;
        int semitone = roundToInt(unroundedSemitone);
        float delta = std::abs(unroundedSemitone - semitone);
        int pitchClass = semitone % numBins;
        if (pitchClass < 0) pitchClass += numBins; // ensure non-negative
        
        // Compute weight based on distance to nearest semitone
        float weight = 1.0f;
        if (useSmoothTransition) {
            weight = smoothTransition(delta);
        }
    
        chroma[pitchClass] += weight * peakMagnitudes[i] * peakMagnitudes[i]; // accumulate squared magnitudes
    }
}

int ChromaConverter::roundToInt(float x) const {
    return static_cast<int>(std::floor(x + 0.5f));
}

// Smooth transition from f(0) = f(a) = 1 to f(b) = f(0.5) = 0
float ChromaConverter::smoothTransition(float x) const {
    float a = 0.3f;
    float b = 0.5f;
     if (x < a) return 1.0f;
    else if (x > b) return 0.0f;
    else return 0.5f *(1.0f + std::cos(M_PI * (x - a) / (b - a)));
}


