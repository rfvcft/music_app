#include "chromaconverter.h"
#include <algorithm>
#include <cmath>
#include <cfloat>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

ChromaConverter::ChromaConverter(std::vector<Peak>& peakBuffer,
                                 std::vector<float>& chromaBuffer): 
    peaks(peakBuffer), chroma(chromaBuffer) { chroma.resize(numBins, 0.0f); } 

// Compute chroma vector from peaks
void ChromaConverter::computeChroma() {
    std::fill(chroma.begin(), chroma.end(), 0.0f);
    if (peaks.empty()) return; 
    if (useOvertoneFilter) {
        computeChromaWithOvertoneFilter();
    } else {
        computeChromaWithoutOvertoneFilter();
    }
}

// Chroma computation without overtone filtering
void ChromaConverter::computeChromaWithoutOvertoneFilter() {
    // Iterate over each peak
    for (const Peak& peak: peaks) {
        // Skip out-of-bounds frequencies
        if (peak.freq < minFrequency || peak.freq > maxFrequency) continue;

        // Compute pitch class 
        float unroundedSemitone = numBins * std::log2f(peak.freq / referenceFrequency) + referencePitchClass;
        int semitone = roundToInt(unroundedSemitone);
        int pitchClass = semitone % numBins;
        if (pitchClass < 0) pitchClass += numBins; // ensure non-negative
        
        // Compute weight based on distance to nearest semitone
        float weight = 1.0f;
        if (useSmoothTransition) weight = smoothTransition(std::abs(unroundedSemitone - semitone));

        chroma[pitchClass] += weight * peak.mag; // accumulate magnitude
    }
}

// Chroma computation with overtone filtering
void ChromaConverter::computeChromaWithOvertoneFilter() {
    // Sort peaks in place by frequency ascending. Needed for monotonic search below
    std::sort(peaks.begin(), peaks.end(), [](const Peak& a, const Peak& b) {
        return a.freq < b.freq;
    });

    // Iterate over each peak 
    for (const Peak& peak: peaks) {
        // Skip out-of-bounds frequencies
        if (peak.freq < minFrequency || peak.freq > maxFrequency) continue;

        // Compute pitch class
        float unroundedSemitone = numBins * std::log2f(peak.freq / referenceFrequency) + referencePitchClass;
        int semitone = roundToInt(unroundedSemitone);
        float weight = 1.0f;
        if (useSmoothTransition) weight = smoothTransition(std::abs(unroundedSemitone - semitone));
        int pitchClass = semitone % numBins;
        if (pitchClass < 0) pitchClass += numBins; 

        // Compute chroma contribution in three steps:
        float chromaContribution = 0.0f;

        // 1. Punish subharmonics
        static const float punishFactors[] = {1.0f/7.0f, 1.0f/6.0f, 1.0f/5.0f, 1.0f/3.0f}; // we don't punish subharmonics at 1/4, 1/2 (same octave)
        size_t hint = 0; // hint index for monotonic search (shared between punish/reward)
        for (float factor : punishFactors) {
            float subharmonicFreq = factor * peak.freq;
            // Skip out-of-bounds frequencies
            if (subharmonicFreq < minFrequency || subharmonicFreq > maxFrequency) continue;

            // Find closest peak to subharmonicFreq
            while (hint + 1 < peaks.size() && peaks[hint].freq < subharmonicFreq) ++hint; // advance hint until we pass target
            const Peak &foundPeak = (hint == 0) // choose closest of peaks[hint] and peaks[hint - 1]
                ? peaks[0]
                : ( (std::fabsf(peaks[hint - 1].freq - subharmonicFreq) <= std::fabsf(peaks[hint].freq - subharmonicFreq)) ? peaks[hint - 1] : peaks[hint] );

            // Punish if close to subharmonicFreq
            float semitoneDelta = numBins * std::fabsf(std::log2f(foundPeak.freq / subharmonicFreq));
            if (semitoneDelta > 0.5f) continue; 
            chromaContribution -= foundPeak.mag;
        }

        // 2. Add fundamental contribution
        float prevMag = peak.mag;
        chromaContribution += prevMag;

        // 3. Reward harmonics
        static const float rewardFactors[] = {2.0f, 3.0f, 4.0f, 5.0f};
        for (float factor : rewardFactors) {
            float harmonicFreq = factor * peak.freq;
            // Skip out-of-bounds frequencies
            if (harmonicFreq < minFrequency || harmonicFreq > maxFrequency) continue;

            // Find closest peak to harmonicFreq
            while (hint + 1 < peaks.size() && peaks[hint].freq < harmonicFreq) ++hint; // advance hint until we pass target
            const Peak &foundPeak = (hint == 0) // choose closest of peaks[hint] and peaks[hint - 1]
                ? peaks[0]
                : ( (std::fabsf(peaks[hint - 1].freq - harmonicFreq) <= std::fabsf(peaks[hint].freq - harmonicFreq)) ? peaks[hint - 1] : peaks[hint] );

            // Reward if close to harmonicFreq
            float semitoneDelta = numBins * std::fabsf(std::log2f(foundPeak.freq / harmonicFreq));
            if (semitoneDelta > 0.5f) break; // break if too far from expected harmonic
            chromaContribution += std::min(prevMag, foundPeak.mag); // harmonic contribution should not exceed previous one
            prevMag = std::min(prevMag, foundPeak.mag);
        }

        // Accumulate to chroma vector
        chroma[pitchClass] += weight * std::max(0.0f, chromaContribution); 
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


