#pragma once
#include <vector>

// Finds local peaks in the magnitude spectrum. Uses parabolic interpolation for better frequency estimation.
class PeakFinder {
public:
    PeakFinder(
        const std::vector<float>& magnitudeBuffer,
        const std::vector<float>& frequencyBuffer,
        std::vector<float>& peakMagBuffer,
        std::vector<float>& peakFreqBuffer
    );

    // Parameters
    int sampleRate = 44100; // sampleRate of audio buffer, in Hz
    int maxPeaks = 4; // maximum number of peaks to detect

    void computePeaks();

private:
    const std::vector<float>& magnitudes; 
    const std::vector<float>& frequencies; 
    std::vector<float>& peakMagnitudes;   
    std::vector<float>& peakFrequencies;  

    struct Peak {
        float mag;
        float freq;
        bool operator<(const Peak& other) const { return mag > other.mag; }
    };
    std::vector<Peak> minHeap; // For tracking top peaks (by magnitude)
    void updateHeap(float mag, float bin);
    
    void parabolicInterpolate(float x1, float y1, float x2, float y2, float x3, float y3, float& interpX, float& interpY) const;
};