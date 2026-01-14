#pragma once

#include <vector>
#include <cmath>

// Removes percussive elements from magnitude spectrum. Based on the paper: 
//
// Harmonic/Percussive separation using median filtering, Derry Fitzgerald, 2010.
//
// The algorithm maintains a history of previous magnitude spectra for computing medians. 
// Edge cases: If it has not seen enough spectra yet, the output is empty. If the input magnitude spectrum is empty,
// it exhausts the internal history. If also the history is exhausted, the output is empty.
class PercussionRemover {
public: 
    PercussionRemover(
        const std::vector<float>& magnitudeBuffer, // Input: magnitude spectrum
        std::vector<float>& noPercussionMagnitudeBuffer // Output: magnitude spectrum with percussion removed
    );

    // Parameters
    int medianLengthInFrames = 17; // Length of the median filter in time frames (must be odd)
    int medianLengthInBins = 33; // Length of the median filter in frequency bins (must be odd)
    float sampleRate = 44100.0f; // Sample rate of the audio signal, in Hz
    int frameSize = 8192; // Frame size used in the STFT, in samples
    int magnitudesSize = frameSize / 2 + 1; // The expected size of the magnitude spectrum 
    float minFrequency = 0.0f; // Minimum frequency to consider, in Hz (the frequency range must be larger than the frequency range in PeakFinder)
    float maxFrequency = 4000.0f; // Maximum frequency to consider, in Hz
    bool deactive = false; // If true, percussion removal is deactivated (output = input)

    void computePercussionRemoval(); 

private:
    const std::vector<float>& magnitudes;
    std::vector<float>& noPercussionMagnitudes;

    int minBin = static_cast<int>(std::round(minFrequency * static_cast<float>(frameSize) / static_cast<float>(sampleRate)));
    int maxBin = static_cast<int>(std::round(maxFrequency * static_cast<float>(frameSize) / static_cast<float>(sampleRate)));

    std::vector<std::vector<float>> magMatrix; // Stores previous magnitudeBuffers (time frames x frequency bins)
    size_t magMatrixRows = medianLengthInFrames; // Number of rows (time frames)
    size_t magMatrixCols = maxBin - minBin + 1; // Number of columns (frequency bins, shifted to minBin..maxBin)
    size_t magHead = 0; // Index of the oldest frame in magMatrix (ring buffer)
    size_t magCount = 0; // How many non-trivial magnitude buffers are in magMatrix
    size_t sufficientMagCount = magMatrixRows / 2 + 1; // magMatrix needs to be at least half full to compute median

    std::vector<std::vector<float>> sortedBinSlices; // bin slices of magMatrix in sorted order (frequency bins x time frames)

    std::vector<float> percussiveMask;
    std::vector<float> harmonicMask;

    void addToMagMatrix(const std::vector<float>& magBuffer);
    void updateInternalStates();
    void computePercussiveMask();
    void computeHarmonicMask();
    void insertIntoBinSlices(const std::vector<float>& frameSlice);
    void eraseFromBinSlices(const std::vector<float>& frameSlice);
};