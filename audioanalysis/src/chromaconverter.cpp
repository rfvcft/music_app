#include "conversion.h"
#include "chromaconverter.h"
#include <algorithm>
#include <cmath>
#include <cfloat>
#include "../third_party/eigen/unsupported/Eigen/NNLS"

// For debugging
//#define DEBUG_CHROMA
#ifdef DEBUG_CHROMA
#include <iostream> 
#include <iomanip> 
#endif

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

ChromaConverter::ChromaConverter(
    std::vector<Peak>& peaks,
    std::vector<float>& chroma,
    float minFrequency,
    float maxFrequency,
    bool octaveReduced,
    int numBins,
    bool useSmoothTransition,
    std::string overtoneFilter
): 
    peaks(peaks), 
    chroma(chroma), 
    minFrequency(minFrequency), 
    maxFrequency(maxFrequency),
    octaveReduced(octaveReduced),
    numBins(numBins), 
    useSmoothTransition(useSmoothTransition), 
    overtoneFilter(overtoneFilter) 
{   
    if (octaveReduced) numBins = 12; // override numBins to 12 if octave reduced
    if (minFrequency < 10.0f) minFrequency = 10.0f; // enforce resonable minimum frequency

    chroma.resize(numBins, 0.0f); 

    // MIDI range for our chroma output
    minOutputMIDI = midiNoteC2; // MIDI note corresponding to chroma bin 0
    maxOutputMIDI = octaveReduced ? midiNoteC6 : midiNoteC2 + numBins; 

    // Assign new values to member variables (parameters shadow member variables)
    this->numBins = numBins;
    this->minFrequency = minFrequency;

    if (overtoneFilter == "nnls") setupNNLS(); // Preallocate space for NNLS
} 

// Compute chroma vector from peaks
void ChromaConverter::computeChroma() {
    std::fill(chroma.begin(), chroma.end(), 0.0f);
    if (peaks.empty()) return; 
    if (overtoneFilter == "none") {
        computeChromaWithoutOvertoneFilter();
    } else if (overtoneFilter == "basic") {
        computeChromaWithBasicOvertoneFilter();
    } else if (overtoneFilter == "nnls") {
        computeChromaWithNNLSOvertoneFilter();
    } else {
        // Should not happen
    } 
}

// Chroma computation without overtone filtering
void ChromaConverter::computeChromaWithoutOvertoneFilter() {
    // Iterate over each peak
    for (const Peak& peak: peaks) {
        // Skip peaks outside our frequency range
        if (peak.freq < minFrequency || peak.freq > maxFrequency) continue; 

        // Compute MIDI note number
        float unroundedMIDINote = frequencyToMIDI(peak.freq);
        int midiNote = static_cast<int>(std::round(unroundedMIDINote));

        // Skip peaks outside our output MIDI range
        if (midiNote < minOutputMIDI || midiNote >= maxOutputMIDI) continue; 

        // Compute weight based on distance to nearest MIDI note
        float weight = 1.0f;
        if (useSmoothTransition) weight = smoothTransition(std::abs(unroundedMIDINote - midiNote));

        // In octave reduced case, accumulate magnitudes of pitch classes
        if (octaveReduced) { 
            int pitchClass = midiNote % 12;
            chroma[pitchClass] += weight * peak.mag; // accumulate magnitude
            continue;
        }
        chroma[midiNote - minOutputMIDI] += weight * peak.mag; 
    }
}

// Chroma computation with overtone filtering
void ChromaConverter::computeChromaWithBasicOvertoneFilter() {
    // Sort peaks in place by frequency ascending. Needed for monotonic search below
    std::sort(peaks.begin(), peaks.end(), [](const Peak& a, const Peak& b) {
        return a.freq < b.freq;
    });

    // Iterate over each peak 
    for (const Peak& peak: peaks) {
        // Skip peaks outside our frequency range
        if (peak.freq < minFrequency || peak.freq > maxFrequency) continue;

        // Compute MIDI note number
        float unroundedMIDINote = frequencyToMIDI(peak.freq);
        int midiNote = static_cast<int>(std::round(unroundedMIDINote));

        // Skip peaks outside our output MIDI range
        if (midiNote < minOutputMIDI || midiNote >= maxOutputMIDI) continue; 
        
        // Compute weight based on distance to nearest MIDI note
        float weight = 1.0f;
        if (useSmoothTransition) weight = smoothTransition(std::abs(unroundedMIDINote - midiNote));

        // Compute chroma contribution in three steps:
        float chromaContribution = 0.0f;

        // 1. Punish subharmonics
        static const float punishFactors[] = {1.0f/7.0f, 1.0f/6.0f, 1.0f/5.0f, 1.0f/4.0f, 1.0f/3.0f, 1.0f/2.0f}; 
        static const float punishWeights[] = {1.0f, 1.0f, 1.0f, 2.0f, 2.0f, 2.0f};
        static const int numPunish = 6; 
        size_t hint = 0; // hint index for monotonic search (shared between punish/reward)
        for (int i = 0; i < numPunish; ++i) {
            float punishFactor = punishFactors[i];
            float punishWeight = punishWeights[i];

            float subharmonicFreq = punishFactor * peak.freq;

            // Skip out-of-bounds frequencies
            if (subharmonicFreq < minFrequency || subharmonicFreq > maxFrequency) continue;

            // Find closest peak to subharmonicFreq
            while (hint + 1 < peaks.size() && peaks[hint].freq < subharmonicFreq) ++hint; // advance hint until we pass target
            const Peak &foundPeak = (hint == 0) // choose closest of peaks[hint] and peaks[hint - 1]
                ? peaks[0]
                : ( (std::fabsf(peaks[hint - 1].freq - subharmonicFreq) <= std::fabsf(peaks[hint].freq - subharmonicFreq)) ? peaks[hint - 1] : peaks[hint] );

            // Punish if close to subharmonicFreq
            float subharmonicMIDINote = frequencyToMIDI(subharmonicFreq);
            float foundMIDINote = frequencyToMIDI(foundPeak.freq);
            float midiDelta = std::fabsf(foundMIDINote - subharmonicMIDINote);
            if (midiDelta > 0.5f) continue; 
            chromaContribution -= punishWeight * foundPeak.mag;
        }

        // 2. Add fundamental contribution
        float prevMag = peak.mag;
        chromaContribution += prevMag;

        // 3. Reward harmonics
        static const float rewardFactors[] = {2.0f, 3.0f, 4.0f, 5.0f, 6.0f, 7.0f, 8.0f};
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
            float harmonicMIDINote = frequencyToMIDI(harmonicFreq);
            float foundMIDINote = frequencyToMIDI(foundPeak.freq);
            float midiDelta = std::fabsf(foundMIDINote - harmonicMIDINote);
            if (midiDelta > 0.5f) break; // break if too far from expected harmonic
            chromaContribution += std::min(prevMag, foundPeak.mag); // harmonic contribution should not exceed previous one
            prevMag = std::min(prevMag, foundPeak.mag);
        }

        // Accumulate to chroma vector
        if (octaveReduced) {
            int pitchClass = midiNote % 12;
            chroma[pitchClass] += weight * std::max(0.0f, chromaContribution); 
            continue;
        }
        chroma[midiNote - minOutputMIDI] += weight * std::max(0.0f, chromaContribution); 
    }
}

void ChromaConverter::setupNNLS() {
    // MIDI range in which we do computations
    minComputationMIDI = static_cast<int>(std::round(frequencyToMIDI(minFrequency))); 
    maxComputationMIDI = static_cast<int>(std::round(frequencyToMIDI(maxFrequency))); 

    // MIDI range in which we search for fundamental frequencies
    minFundamentalMIDI = minComputationMIDI; // as low as possible
    maxFundamentalMIDI = std::min(octaveReduced ? midiNoteC6 : midiNoteC2 + numBins, maxComputationMIDI); // up to C2 + numBins or C6 (if octave reduced), capped by maxiumComputation range

    // Preallocate space for NNLS
    int numComputation = maxComputationMIDI - minComputationMIDI;
    A.resize(numComputation, numCandidates);
    b.resize(numComputation);
    x.resize(numCandidates);
    largestElements.reserve(numCandidates); 
}

// Filter fundamental frequencies from peak spectrum by using a overtone mask computed with NNLS
void ChromaConverter::computeChromaWithNNLSOvertoneFilter() {
    if (minFundamentalMIDI >= maxFundamentalMIDI) return; // should not happen

    // Size of MIDI vectors we need
    int numComputation = maxComputationMIDI - minComputationMIDI; 

    // Construct the rhs of the NNLS problem
    b.setZero();
    for (const Peak& peak : peaks) {
        float unroundedMIDINote = frequencyToMIDI(peak.freq);
        int midiNote = static_cast<int>(std::round(unroundedMIDINote));
        float weight = 1.0f;
        if (useSmoothTransition) weight = smoothTransition(std::abs(unroundedMIDINote - midiNote));
        if (minComputationMIDI <= midiNote && midiNote < maxComputationMIDI) { // Only consider peaks that fall into our computation MIDI range
            b(midiNote - minComputationMIDI) += peak.mag * weight; // Accumulate magnitudes for peaks that fall into the same MIDI bin
        }
    }

    // Find largest entries in b within the fundamentalMIDI range
    largestElements.clear();
    for (int midiNote = minFundamentalMIDI; midiNote < maxFundamentalMIDI; ++midiNote) {
        int i = midiNote - minComputationMIDI;
        float magnitude = (i >= 0 && i < b.size()) ? b(i) : 0.0f;
        largestElements.emplace_back(magnitude, midiNote);
    }
    std::sort(largestElements.begin(), largestElements.end(), [](const std::pair<float, int>& a, const std::pair<float, int>& b) {
        return a.first > b.first; // Sort by magnitude descending
    });

    // Construct the matrix of the NNLS problem
    A.setZero();
    for (int j = 0; j < std::min(numCandidates, static_cast<int>(largestElements.size())); ++j) { // Use numCandidates strongest midiNotes as candidates for fundamentals
        int midiNote = largestElements[j].second;
        for (int k = 0; k < std::min(overtonePattern.size(), overtoneWeights.size()); ++k) {
            int i = midiNote - minComputationMIDI + overtonePattern[k];
            if (i >= 0 && i < numComputation) {
                A(i, j) = overtoneWeights[k];
            }
        }
    }
    
    // Solve NNLS problem
    Eigen::NNLS<Eigen::MatrixXd> nnls(A);
    x = nnls.solve(b);

    // Convert NNLS solution to MIDI chroma contributions
    for (int j = 0; j < std::min(static_cast<int>(x.size()), static_cast<int>(largestElements.size())); ++j) {
        float magnitude = largestElements[j].first;
        int midiNote = largestElements[j].second;
        float mask = x(j);

        if (octaveReduced) {
            int pitchClass = midiNote % numBins;
            chroma[pitchClass] += magnitude * mask; 
        } else {
            if (minOutputMIDI <= midiNote && midiNote < maxOutputMIDI) { // Only consider contributions that fall into our output MIDI range
                chroma[midiNote - minOutputMIDI] += magnitude * mask; 
            }
        }
    }

    // Debugging output
#ifdef DEBUG_CHROMA
    /*
    std::cout << "First column of matrix A :\n";
    int j = 0;
    for (int i = 0; i < A.rows(); ++i) {
        std::cout << "Index: i = " << i;
        std::cout << std::fixed << std::setprecision(1) << std::setw(5) << A(i, j) << " " << std::endl;
    }
    */

    std::cout << "Strongest elements:\n";
    for (int i = 0; i < std::min(numCandidates, static_cast<int>(largestElements.size())); ++i) {
        std::cout << "MIDI note " << largestElements[i].second << ", magnitude:  " << largestElements[i].first << std::endl;
    }

    Eigen::VectorXd Ax = A * x;
    std::cout << "Vector b, approximation Ax, and difference (b - Ax):\n";
    for (int i = 0; i < b.size(); ++i) {
        if (b(i) > 0.01f) { // Print only significant values
            std::cout << "MIDI note " << i + minComputationMIDI << ": "
                      << std::fixed << std::setprecision(2)
                      << std::setw(8) << b(i) << " "
                      << std::setw(8) << Ax(i) << " "
                      << std::setw(8) << (b(i) - Ax(i)) << std::endl;
        }
    }

    std::cout << "Resulting chroma vector:\n";
    for (int i = 0; i < chroma.size(); ++i) {
        if (chroma[i]> 0.01f) {
            std::cout << "MIDI note " << i + minOutputMIDI << ": " << chroma[i] << std::endl;
        }
    }
#endif
}

// Smooth transition from f(0) = f(a) = 1 to f(b) = f(0.5) = 0
float ChromaConverter::smoothTransition(float x) const {
    float a = 0.3f;
    float b = 0.5f;
     if (x < a) return 1.0f;
    else if (x > b) return 0.0f;
    else return 0.5f *(1.0f + std::cos(M_PI * (x - a) / (b - a)));
}


