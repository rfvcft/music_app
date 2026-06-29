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

// Function to solve: min ||Ax - b||_2^2 + lambda * ||x||_1 under x >= 0
Eigen::VectorXd solve_nnls_l1(const Eigen::MatrixXd& A, const Eigen::VectorXd& b, double lambda, double tol = 1e-6, int max_iter = 1000) {
    int n = A.cols();
    Eigen::VectorXd x = Eigen::VectorXd::Zero(n); // Start vector of zeros

    if (n == 0) return x;
    if (lambda < 0.0) { // Call built in solver for min ||Ax - b||_2^2 under x >= 0
        Eigen::NNLS<Eigen::MatrixXd> nnls(A);
        x = nnls.solve(b);
        return x;
    }
    
    // Precompute the gradient terms
    Eigen::MatrixXd AtA = A.transpose() * A;
    Eigen::VectorXd Atb = A.transpose() * b;
    
    // Compute the Lipschitz constant (largest eigenvalue of AtA) for the step size.
    // For a quick estimate, we could use the Frobenius norm or power iteration.
    // Here we use the maximum column sum norm as a conservative estimate for L.
    double L = 2.0 * AtA.operatorNorm();
    if (L <= 1e-12) return x;
    double step = 1.0 / L;
    
    Eigen::VectorXd c = -2.0 * Atb;
    Eigen::MatrixXd Q = 2.0 * AtA;
    
    Eigen::VectorXd x_old;
    
    for (int iter = 0; iter < max_iter; ++iter) {
        x_old = x;
        
        // 1. Gradient step: x = x - step * (Q*x + c)
        Eigen::VectorXd grad = Q * x + c;
        x = x - step * grad;
        
        // 2. Proximal operator for L1 regularization and non-negativity (x >= 0).
        // Since x must be non-negative, the negative soft-thresholding part drops out.
        double thresh = lambda * step;
        for (int i = 0; i < n; ++i) {
            x(i) = std::max(0.0, x(i) - thresh);
        }
        
        // Konvergenzprüfung
        if ((x - x_old).norm() < tol) {
            break;
        }
    }
    
    return x;
}


ChromaConverter::ChromaConverter(
    std::vector<Peak>& peaks,
    std::vector<float>& chroma,
    float minFrequency,
    float maxFrequency,
    int numBins,
    bool useSmoothTransition,
    std::string overtoneFilter
): 
    peaks(peaks), 
    chroma(chroma), 
    minFrequency(minFrequency), 
    maxFrequency(maxFrequency),
    numBins(numBins), 
    useSmoothTransition(useSmoothTransition), 
    overtoneFilter(overtoneFilter) 
{   
    if (minFrequency < 10.0f) minFrequency = 10.0f; // enforce resonable minimum frequency

    chroma.resize(numBins, 0.0f); 

    // MIDI range for our chroma output
    minOutputMIDI = midiNoteC1; // MIDI note corresponding to chroma bin 0
    maxOutputMIDI = midiNoteC1 + numBins; 

    // Assign new values to member variables (parameters shadow member variables)
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
        static const float punishWeights[] = {0.5f, 0.6f, 0.7f, 0.8f, 0.9f, 1.0f}; // TODO choose smarter
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
        static const float rewardWeights[] = {0.9f, 0.8f, 0.7f, 0.6f, 0.5f, 0.4f, 0.3f}; // TODO choose smarter
        static const int numReward = 7;
        for (int i = 0; i < numReward; ++i) {
            float factor = rewardFactors[i];
            float weight = rewardWeights[i];
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
            chromaContribution += weight * std::min(prevMag, foundPeak.mag); // harmonic contribution should not exceed previous one
            prevMag = std::min(prevMag, foundPeak.mag);
        }

        // Accumulate to chroma vector
        chroma[midiNote - minOutputMIDI] += weight * std::max(0.0f, chromaContribution); 
    }
}

void ChromaConverter::setupNNLS() {
    // MIDI range in which we do computations
    minComputationMIDI = static_cast<int>(std::round(frequencyToMIDI(minFrequency))); 
    maxComputationMIDI = static_cast<int>(std::round(frequencyToMIDI(maxFrequency))); 

    // MIDI range in which we search for fundamental frequencies
    minFundamentalMIDI = std::max(midiNoteA1, minOutputMIDI); // Starting at A1, lower frequencies are to difficult to distinguish, capped by minOutputMIDI
    maxFundamentalMIDI = std::min(maxComputationMIDI, maxOutputMIDI); // up to output, capped by maxComputationMIDI

    // Preallocate space for NNLS
    numBinsComputation = maxComputationMIDI - minComputationMIDI;
    A.resize(numBinsComputation, numCandidates);
    b.resize(numBinsComputation);
    x.resize(numCandidates);
    largestElements.reserve(numCandidates); 
}

// Filter fundamental frequencies from peak spectrum by using a overtone mask computed with NNLS
void ChromaConverter::computeChromaWithNNLSOvertoneFilter() {
    if (minFundamentalMIDI >= maxFundamentalMIDI) return; // should not happen

    // Construct the rhs b of the NNLS problem
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

    // Find largest entries in b and store them in largestElements as pairs of (magnitude, MIDI note)
    largestElements.clear(); 
    for (int midiNote = minFundamentalMIDI; midiNote < maxFundamentalMIDI; ++midiNote) { // Only consider candidates within fundamental MIDI range
        int i = midiNote - minComputationMIDI;
        float magnitude = (i >= 0 && i < b.size()) ? b(i) : 0.0f;
        if (magnitude > 0.0f) largestElements.emplace_back(magnitude, midiNote);
    }

    std::sort(largestElements.begin(), largestElements.end(), [](const std::pair<float, int>& a, const std::pair<float, int>& b) { // Sort by magnitude descending
        return a.first > b.first;  
    });
    
    largestElements.resize(std::min(static_cast<int>(largestElements.size()), numCandidates)); // Keep only numCandidates elements at most

    float totalMagnitude = 0.0f; // Only keep elements with sufficiently large magnitude compared to average of the largest elements
    for (const auto& el : largestElements) totalMagnitude += el.first;
    float averageMagnitude = largestElements.empty() ? 0.0f : totalMagnitude / largestElements.size();
    float magnitudeThreshold = relativeThresholdForCandidateSelection * averageMagnitude;
    for (size_t i = 0; i < largestElements.size(); ++i) {
        if (largestElements[i].first < magnitudeThreshold) {
            largestElements.resize(i); // Keep only candidates above threshold
            break;
        }
    }

    if (largestElements.empty()) return;

    // Construct the matrix of the NNLS problem
    A.setZero();
    for (size_t j = 0; j < largestElements.size(); ++j) { // Use numCandidates strongest midiNotes as candidates for fundamentals
        int midiNote = largestElements[j].second;
        for (int k = 0; k < std::min(overtonePattern.size(), overtoneWeights.size()); ++k) {
            int i = midiNote - minComputationMIDI + overtonePattern[k];
            if (i >= 0 && i < numBinsComputation) {
                A(i, j) = overtoneWeights[k];
            }
        }
    }
    
    // Solve NNLS problem
    x = solve_nnls_l1(A, b, lambdaL1);

    // Convert NNLS solution to chroma contributions
    for (size_t j = 0; j < largestElements.size(); ++j) {
        float magnitude = largestElements[j].first; // original magnitude of this candidate fundamental frequency (not needed below)
        int midiNote = largestElements[j].second; // MIDI note of this candidate fundamental frequency
        float nnlsFundamentalMagnitude = x(j); // weight assigned by NNLS to this candidate fundamental frequency

        if (minOutputMIDI <= midiNote && midiNote < maxOutputMIDI) { // Only consider contributions that fall into our output MIDI range
            float contribution = 0.0f;
            for (int k = 0; k < std::min(overtonePattern.size(), overtoneWeights.size()); ++k) { // Contribution = <x(j)A e_j, b> where e_j is the j-th standard basis vector
                int harmonicMIDI = midiNote + overtonePattern[k];
                int harmonicMIDIIndex = harmonicMIDI - minComputationMIDI; // shifted index for accessing b
                float nnlsHarmonicMagnitude = overtoneWeights[k] * nnlsFundamentalMagnitude; 
                float originalMagnitude = (harmonicMIDIIndex >= 0 && harmonicMIDIIndex < b.size()) ? b(harmonicMIDIIndex) : 0.0f;
                contribution += nnlsHarmonicMagnitude * originalMagnitude;
            }
            chroma[midiNote - minOutputMIDI] += contribution; 
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


