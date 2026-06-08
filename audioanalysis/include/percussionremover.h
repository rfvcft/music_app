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
        const std::vector<float>& magnitudes, // Input: magnitude spectrum
        std::vector<float>& noPercussionMagnitudes, // Output: magnitude spectrum with percussion removed
        int sampleRate, // Parameter: sample rate of the audio signal, in Hz (Default: 44100)
        int frameSize, // Parameter: frame size used in the STFT, in samples (Default: 8192)
        int hopSize, // Parameter: hop size used in the STFT, in samples (Default: 1024)
        float medianLengthInSeconds, // Parameter: length of median filter in seconds (Default: 0.39s)
        float medianLengthInHertz, // Parameter: length of median filter in Hz (Default: 183.0 Hz)
        float minFrequency, // Parameter: minimum frequency to consider, in Hz (the frequency range must be larger than the frequency range in PeakFinder) (Default: 0.0 Hz)
        float maxFrequency, // Parameter: maximum frequency to consider, in Hz (the frequency range must be larger than the frequency range in PeakFinder) (Default: 4000.0 Hz)
        bool deactive // Parameter: if true, percussion removal is deactivated (output = input) (Default: false)
    );

    int medianLengthInFrames; // Length of the median filter in time frames
    int medianLengthInBins; // Length of the median filter in frequency bins 

    void computePercussionRemoval(); // Remove percussive elements from magnitude spectra 
    bool isFinished(); // returns true if the internal history is exhausted and no more output can be produced
    bool hasNotSeenEnoughFrames(); // returns true if not enough frames have been seen yet to produce output

private:
    const std::vector<float>& magnitudes;
    std::vector<float>& noPercussionMagnitudes;
    float sampleRate;
    int frameSize;
    int hopSize;
    float medianLengthInSeconds;
    float medianLengthInHertz;
    float minFrequency;
    float maxFrequency;
    bool deactive;

    int minBin;
    int maxBin;
    
    std::vector<std::vector<float>> magMatrix; // Stores previous magnitudeBuffers (time frames x frequency bins)
    int magnitudesSize; // Size of the input magnitude buffers (number of frequency bins)
    size_t magMatrixRows; // Number of rows (time frames)
    size_t magMatrixCols; // Number of columns (frequency bins, shifted to minBin..maxBin)
    size_t magHead = 0; // Index of the oldest frame in magMatrix (ring buffer)
    int magCount = 0; // How many non-trivial magnitude buffers are in magMatrix
    int sufficientMagCount; // magMatrix needs to be at least half full to compute median

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