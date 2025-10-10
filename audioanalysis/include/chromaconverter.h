#pragma once
#include <vector>
#include <cmath>

// Converts peak magnitudes and corresponding frequencies to a chroma vector (12 pitch classes).
class ChromaConverter {
public:
    ChromaConverter(
        const std::vector<float>& peakMagBuffer, // Input: peak magnitudes
        const std::vector<float>& peakFreqBuffer, // Input: corresponding peak frequencies
        std::vector<float>& chromaBuffer // Output: chroma vector (pitch classes)
    );

    // Parameters
    int numBins = 12; // number of chroma bins (typically 12 for semitones)
    float referenceFrequency = 440.0f; // reference frequency for A4, in Hz
    int referencePitchClass = 9; // reference pitch class for A (0=C, 1=C#, ..., 9=A, ..., 11=B)
    float minFrequency = 100.0f; // minimum frequency to consider, in Hz
    float maxFrequency = 5000.0f; // maximum frequency to consider, in Hz
    bool useSmoothTransition = true; // Use smooth transition at semitone boundaries

    void computeChroma();

private:
    const std::vector<float>& peakMagnitudes; 
    const std::vector<float>& peakFrequencies; 
    std::vector<float>& chroma; 

    int roundToInt(float x) const;
    float smoothTransition(float x) const;
    float otherSmoothTransition(float x) const;
};