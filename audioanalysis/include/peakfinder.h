#pragma once
#include <vector>

// Container for tuple of magnitude and frequency of a peak
struct Peak {
    float mag; // magnitude of peak
    float freq; // frequency of peak
    bool operator<(const Peak& other) const { return mag > other.mag; } // peaks are compared by magnitude
};

// Finds local peaks in the magnitude spectrum. Uses parabolic interpolation for better frequency estimation.
class PeakFinder {
public:
    PeakFinder(
        const std::vector<float>& magnitudes, // Input: magnitude spectrum (size frameSize/2 + 1)
        std::vector<Peak>& peaks, // Output: peaks of magnitudes spectrum (magnitude and frequency)
        int sampleRate, // Parameter: sample rate corresponding to the magnitude spectrum, in Hz
        int frameSize, // Parameter: frame size corresponding to the magnitude spectrum (used for frequency computations)
        float minFrequency, // Parameter: minimum frequency to consider, in Hz (Default: 40.0 Hz)
        float maxFrequency, // Parameter: maximum frequency to consider, in Hz (Default: 3500.0 Hz)
        int maxPeaks // Parameter: maximum number of peaks to detect (Default: 30)
    );

    void computePeaks();

private:
    const std::vector<float>& magnitudes; 
    std::vector<Peak>& peaks;   
    int sampleRate;
    int frameSize;
    float minFrequency;
    float maxFrequency;
    int maxPeaks;

    int roundToInt(float x) const;
    float binToFrequency(float bin) const;
    float frequencyToBin(float frequency) const;
    void updateHeap(Peak peak);
    Peak parabolicInterpolate(int bin1, float mag1, int bin2, float mag2, int bin3, float mag3) const;
};