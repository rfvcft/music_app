#include "peakfinder.h"
#include <vector>
#include <cmath>
#include <algorithm>


PeakFinder::PeakFinder(const std::vector<float>& magnitudeBuffer,
                          std::vector<Peak>& peakBuffer)
    : magnitudes(magnitudeBuffer), peaks(peakBuffer) {
                peaks.reserve(maxPeaks);
      }

// Find local peaks in magnitude spectrum. We only consider peaks within [minFrequency, maxFrequency].  
void PeakFinder::computePeaks() {
    peaks.clear();
    if (magnitudes.empty()) return; 

    int K = magnitudes.size();

    // Convert frequency bounds to bin indices
    float minBin = frequencyToBin(minFrequency);
    float maxBin = frequencyToBin(maxFrequency);

    int minIndex = std::max(roundToInt(minBin), 1);
    int maxIndex = std::min(roundToInt(maxBin), K - 2);

    // Search for local peaks
    for (int i = minIndex; i <= maxIndex; ++i) {
        if (magnitudes[i] > magnitudes[i - 1] && magnitudes[i] > magnitudes[i + 1]) {
            // Local peak, apply parabolic interpolation
            Peak peak = parabolicInterpolate(i - 1, magnitudes[i - 1], i, magnitudes[i], i + 1, magnitudes[i + 1]);
            updateHeap(peak);
        } else if (magnitudes[i] == magnitudes[i + 1]) {
            int j = i + 1;
            while (j + 1 < K && magnitudes[j] == magnitudes[j + 1]) ++j;
            if (magnitudes[j] > magnitudes[j + 1]) {
                // Plateau peak, take center frequency
                float meanBin = 0.5f * (i + j); 
                float meanFreq = binToFrequency(meanBin);
                Peak peak = Peak{magnitudes[i], meanFreq};
                updateHeap(peak);
                i = j;
            }
        }
    }
}

int PeakFinder::roundToInt(float x) const {
    return static_cast<int>(std::floor(x + 0.5f));
}

// Convert bin index to frequency in Hz
float PeakFinder::binToFrequency(float bin) const {
    int N = (magnitudes.size() - 1) * 2; // since magnitudes size is N/2 + 1
    return bin * static_cast<float>(sampleRate) / static_cast<float>(N);
}

// Convert frequency in Hz to bin index
float PeakFinder::frequencyToBin(float frequency) const {
    int N = (magnitudes.size() - 1) * 2; // since magnitudes size is N/2 + 1
    return frequency * static_cast<float>(N) / static_cast<float>(sampleRate);
}

// Maintain a max-heap of peaks. We only keep the top maxPeaks peaks.
void PeakFinder::updateHeap(Peak peak) {
    if ((int)peaks.size() < maxPeaks) {
        peaks.push_back(peak);
        std::push_heap(peaks.begin(), peaks.end());
    } else if (peak.mag > peaks.front().mag) {
        std::pop_heap(peaks.begin(), peaks.end());
        peaks.back() = peak;
        std::push_heap(peaks.begin(), peaks.end());
    }
}

// Parabolic interpolation: fit a parabola through (bin1, mag1), (bin2, mag2), (bin3, mag3)
// and find the maximum (interpBin, interpMag). Then convert interpBin to frequency interpFreq. Returns Peak{interpMag, interpFreq}
Peak PeakFinder::parabolicInterpolate(int bin1, float mag1, int bin2, float mag2, int bin3, float mag3) const {
    float interpBin = bin2;
    float interpMag = mag2;

    float denom = (bin1 - bin2) * (bin1 - bin3) * (bin2 - bin3);
    if (denom == 0.0f) {
        float interpFreq = binToFrequency(interpBin);
        return Peak{interpMag, interpFreq};
    }

    float a = (bin3 * (mag2 - mag1) + bin2 * (mag1 - mag3) + bin1 * (mag3 - mag2)) / denom;
    float b = (bin3*bin3 * (mag1 - mag2) + bin2*bin2 * (mag3 - mag1) + bin1*bin1 * (mag2 - mag3)) / denom;

    interpBin = -b / (2.0f * a);
    interpMag = a * interpBin * interpBin + b * interpBin + (mag1 - a * bin1 * bin1 - b * bin1);

    float interpFreq = binToFrequency(interpBin);
    return Peak{interpMag, interpFreq};
}
