#include "peakfinder.h"
#include <vector>
#include <cmath>
#include <algorithm>

PeakFinder::PeakFinder(const std::vector<float>& magnitudeBuffer,
                        const std::vector<float>& frequencyBuffer,
                       std::vector<float>& peakMagBuffer,
                       std::vector<float>& peakFreqBuffer)
    : magnitudes(magnitudeBuffer), frequencies(frequencyBuffer), peakMagnitudes(peakMagBuffer), peakFrequencies(peakFreqBuffer) {
        peakMagnitudes.reserve(maxPeaks);
        peakFrequencies.reserve(maxPeaks);
        minHeap.reserve(maxPeaks);
      }

void PeakFinder::computePeaks() {
    peakMagnitudes.clear();
    peakFrequencies.clear();
    minHeap.clear();

    int K = magnitudes.size();

    for (int i = 1; i < K - 1; ++i) {
        if (magnitudes[i] > magnitudes[i - 1] && magnitudes[i] > magnitudes[i + 1]) {
            // Local peak, apply parabolic interpolation
            float interpolatedFreq, interpolatedMag;
            parabolicInterpolate(frequencies[i - 1], magnitudes[i - 1], frequencies[i], magnitudes[i], frequencies[i + 1], magnitudes[i + 1], interpolatedFreq, interpolatedMag);
            updateHeap(interpolatedMag, interpolatedFreq);
        } else if (magnitudes[i] == magnitudes[i + 1]) {
            int j = i + 1;
            while (j + 1 < K && magnitudes[j] == magnitudes[j + 1]) ++j;
            if (magnitudes[j] > magnitudes[j + 1]) {
                // Plateau peak, take center frequency
                float meanFreq = 0.5f * (frequencies[i] + frequencies[j]); // Here we assume that frequencies are linearly spaced!
                updateHeap(magnitudes[i], meanFreq);
                i = j;
            }
        }
    }

    // Sort peaks by magnitude descending
    //std::sort(minHeap.begin(), minHeap.end());

    for (const auto& p : minHeap) {
        peakMagnitudes.push_back(p.mag);
        peakFrequencies.push_back(p.freq);
    }
}

void PeakFinder::updateHeap(float mag, float freq) {
    if ((int)minHeap.size() < maxPeaks) {
        minHeap.push_back(Peak{mag, freq});
        std::push_heap(minHeap.begin(), minHeap.end());
    } else if (mag > minHeap.front().mag) {
        std::pop_heap(minHeap.begin(), minHeap.end());
        minHeap.back() = Peak{mag, freq};
        std::push_heap(minHeap.begin(), minHeap.end());
    }
}

void PeakFinder::parabolicInterpolate(float x1, float y1, float x2, float y2, float x3, float y3, float& interpX, float& interpY) const {
    // Parabolic interpolation: fit a parabola through (x1, y1), (x2, y2), (x3, y3)
    // and find the vertex (maximum)
    float denom = (x1 - x2) * (x1 - x3) * (x2 - x3);
    if (denom == 0.0f) {
        interpX = x2;
        interpY = y2;
        return;
    }
    float a = (x3 * (y2 - y1) + x2 * (y1 - y3) + x1 * (y3 - y2)) / denom;
    float b = (x3*x3 * (y1 - y2) + x2*x2 * (y3 - y1) + x1*x1 * (y2 - y3)) / denom;
    interpX = -b / (2.0f * a);
    interpY = a * interpX * interpX + b * interpX + (y1 - a * x1 * x1 - b * x1);
}
