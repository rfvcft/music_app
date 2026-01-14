#include "chromaenhancer.h"
#include <algorithm>
#include <cmath>
#include <vector>
#include <set>
#include <cassert>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

ChromaEnhancer::ChromaEnhancer(const std::vector<std::vector<float>>& inputChroma, std::vector<std::vector<float>>& outputChroma)
                               : chromaMatrix(inputChroma), enhancedChromaMatrix(outputChroma){}

// Enhance inputChroma and write to outputChroma
void ChromaEnhancer::computeEnhancement() {
    convertToLogScale();
    dropLowAmplitudes(lowAmplitudeThreshold);
    medianTimeFilterSliding(medianFilterWindowSize);
    dropShortTimeExcitations(minDuration); 
    normalizeChroma(normalize); // typically bypassed
}

// Convert chroma values to log scale and resize to [0, 1]
void ChromaEnhancer::convertToLogScale() {
    size_t numFrames = chromaMatrix.size();
    if (numFrames == 0) return;
    size_t numBins = chromaMatrix[0].size();
    enhancedChromaMatrix.assign(numFrames, std::vector<float>(numBins, 0.0f));

    // Find global max
    float maxChroma = 0.0f;
    for (const auto& frame : chromaMatrix)
        for (float v : frame) maxChroma = std::max(maxChroma, v);

    // Convert to log scale and resize to [0, 1]
    float eps = 1e-12f; // small constant to avoid log(0)
    if (maxChroma <= 10 * eps) return;
    float denom = std::logf(maxChroma) - std::logf(eps);
    for (size_t t = 0; t < numFrames; ++t) {
        for (size_t k = 0; k < numBins; ++k) {
            float v = chromaMatrix[t][k];
            if (v < eps) v = 0.0f;
            else v = (std::logf(v) - std::logf(eps)) / denom;
            enhancedChromaMatrix[t][k] = v;
        }
    }
}

// Drop chroma values below threshold and resize to [0, 1]
void ChromaEnhancer::dropLowAmplitudes(float threshold) {
    size_t numFrames = enhancedChromaMatrix.size();
    if (numFrames == 0) return;
    size_t numBins = enhancedChromaMatrix[0].size();

    for (size_t t = 0; t < numFrames; ++t) {
        for (size_t k = 0; k < numBins; ++k) {
            float v = enhancedChromaMatrix[t][k];
            // Thresholding
            if (v < threshold) v = 0.0f;
            else v = (v - threshold) / (1.0f - threshold);
            enhancedChromaMatrix[t][k] = v;
        }
    }
}

// Drop chroma excitations shorter than minDurationFrames
void ChromaEnhancer::dropShortTimeExcitations(int minDurationFrames) {
    if (minDurationFrames <= 0) return; // bypass

    size_t numFrames = chromaMatrix.size();
    if (numFrames == 0) return;
    size_t numBins = chromaMatrix[0].size();

    float intensityThreshold = 0.05f;

    for (size_t k = 0; k < numBins; ++k) {
        int count = 0;
        for (size_t t = 0; t < numFrames; ++t) {
            if (enhancedChromaMatrix[t][k] > intensityThreshold) {
                count++;
            } else {
                if (count > 0 && count < minDurationFrames) {
                    // Zero out the short activation
                    for (int back = 1; back <= count; ++back) {
                        enhancedChromaMatrix[t - back][k] = 0.0f;
                    }
                }
                count = 0;
            }
        }
        // Handle case where activation goes till the end
        if (count > 0 && count < minDurationFrames) {
            for (int back = 1; back <= count; ++back) {
                enhancedChromaMatrix[numFrames - back][k] = 0.0f;
            }
        }
    }
}


// Sliding median with edge zero padding.
// Force windowSize to be odd; we maintain a sorted vector for the window and
// perform remove/insert using binary search (O(windowSize) per slide due to vector erase/insert).
std::vector<float> sliding_median(const std::vector<float>& in, int windowSize) {
    if (windowSize <= 1) return in; // no filtering
    assert(windowSize >= 1);
    int w = windowSize;
    // force odd window size
    if ((w % 2) == 0) ++w;

    int n = static_cast<int>(in.size());
    if (n == 0) return {};

    int half = w / 2;

    // Build padded array: zero-pad at both ends
    std::vector<float> p;
    p.reserve(n + 2 * half);
    for (int i = 0; i < half; ++i) p.push_back(0.0f);
    p.insert(p.end(), in.begin(), in.end());
    for (int i = 0; i < half; ++i) p.push_back(0.0f);

    // initialize sorted window with first w elements
    std::vector<float> window;
    window.reserve(w);
    for (int i = 0; i < w; ++i) window.push_back(p[i]);
    std::sort(window.begin(), window.end());

    std::vector<float> out(n);
    for (int t = 0; t < n; ++t) {
        // median is the middle element (w is odd)
        out[t] = window[half];
        if (t + w >= static_cast<int>(p.size())) break; // no next window

        float rem = p[t];
        float addv = p[t + w];

        // remove one instance of rem (use lower_bound then tolerate tiny differences)
        auto it = std::lower_bound(window.begin(), window.end(), rem);
        if (it != window.end() && std::fabs(*it - rem) <= 1e-6f) {
            window.erase(it);
        } else {
            // fallback: linear search for a close match
            auto fit = std::find_if(window.begin(), window.end(), [&](float x){ return std::fabs(x - rem) <= 1e-6f; });
            if (fit != window.end()) window.erase(fit);
            else {
                // last-resort: erase the element at lower_bound (keeps window size correct)
                if (it != window.end()) window.erase(it);
                else window.erase(window.begin());
            }
        }

        // insert addv keeping sorted order
        auto pos = std::lower_bound(window.begin(), window.end(), addv);
        window.insert(pos, addv);
    }

    return out;
}

// Sliding median in time (per bin)
void ChromaEnhancer::medianTimeFilterSliding(int windowSize) {
    size_t numFrames = enhancedChromaMatrix.size();
    if (numFrames == 0) return;
    size_t numBins = enhancedChromaMatrix[0].size();

    // create an output matrix with the same shape but zero-initialized
    std::vector<std::vector<float>> outMatrix(numFrames, std::vector<float>(numBins, 0.0f));

    std::vector<float> binSlice; // temporary storage for one bin across all frames
    binSlice.reserve(numFrames);
    for (size_t bin = 0; bin < numBins; ++bin) {
        binSlice.clear();
        for (size_t frame = 0; frame < numFrames; ++frame) {
            binSlice.push_back(enhancedChromaMatrix[frame][bin]);
        }
        std::vector<float> filtered = sliding_median(binSlice, windowSize);
        for (size_t frame = 0; frame < numFrames; ++frame) {
            outMatrix[frame][bin] = filtered[frame];
        }
    }
    enhancedChromaMatrix.swap(outMatrix);
}

// Normalize each chroma vector using max norm
void ChromaEnhancer::normalizeChroma(bool normalize) {
    if (!normalize) return; // bypass

    size_t numFrames = enhancedChromaMatrix.size();
    if (numFrames == 0) return;
    size_t numBins = enhancedChromaMatrix[0].size();

    for (size_t t = 0; t < numFrames; ++t) {
        float maxVal = 0.0f;
        for (size_t k = 0; k < numBins; ++k) {
            maxVal = std::max(maxVal, enhancedChromaMatrix[t][k]);
        }
        if (maxVal > 1e-6f) {
            for (size_t k = 0; k < numBins; ++k) {
                enhancedChromaMatrix[t][k] /= maxVal;
            }
        }
    }
}