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
        const std::vector<float>& magnitudeBuffer, // Input: magnitude spectrum
        std::vector<Peak>& peakBuffer // Output: peaks of magnitudes spectrum (magnitude and frequency)
    );

    // Parameters
    int maxPeaks = 30; // maximum number of peaks to detect
    int sampleRate = 44100; // sampleRate corresponding to the magnitude spectrum
    float minFrequency = 40.0f; // minimum frequency to consider, in Hz
    float maxFrequency = 3500.0f; // maximum frequency to consider, in Hz

    void computePeaks();

private:
    const std::vector<float>& magnitudes; 
    std::vector<Peak>& peaks;   

    int roundToInt(float x) const;
    float binToFrequency(float bin) const;
    float frequencyToBin(float frequency) const;
    void updateHeap(Peak peak);
    Peak parabolicInterpolate(int bin1, float mag1, int bin2, float mag2, int bin3, float mag3) const;
};