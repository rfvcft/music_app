#pragma once
#include "peakfinder.h" // for Peak struct 
#include <vector>
#include <cmath>


// Converts magnitude peaks to a 12 dimensional chroma vector (pitch classes). Overtones are filtered. 
class ChromaConverter {
public:
    ChromaConverter(
        std::vector<Peak>& peakBuffer, // Input: peaks (magnitude and frequency) 
        std::vector<float>& chromaBuffer // Output: chroma vector (pitch classes)
    );

    // Parameters
    int numBins = 12; // number of chroma bins (typically 12 for semitones)
    float referenceFrequency = 220.0f; // reference frequency for A3, in Hz
    int referencePitchClass = 9; // reference pitch class for A (0=C, 1=C#, ..., 9=A, ..., 11=B)
    float minFrequency = 40.0f; // minimum frequency to consider, in Hz
    float maxFrequency = 3500.0f; // maximum frequency to consider, in Hz
    bool useSmoothTransition = true; // Use smooth transition at semitone boundaries
    bool useOvertoneFilter = true; // Whether to use overtone filtering. As a side effect, this will sort peakBuffer in-place

    void computeChroma();

private:
    std::vector<Peak>& peaks;
    std::vector<float>& chroma; 

    void computeChromaWithOvertoneFilter();
    void computeChromaWithoutOvertoneFilter();
    int roundToInt(float x) const;
    float smoothTransition(float x) const;
};