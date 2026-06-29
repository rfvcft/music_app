#include "conversion.h"
#include "chromaenhancer.h"
#include <algorithm>
#include <cmath>
#include <vector>
#include <set>
#include <cassert>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

ChromaEnhancer::ChromaEnhancer(
    const std::vector<std::vector<float>>& chromaMatrix,
    std::vector<std::vector<float>>& enhancedChromaMatrix,
    int sampleRate,
    int hopSize,
    float localMaxWindowSizeInSeconds,
    float lowAmplitudeThreshold,
    float medianLengthInSeconds,
    float minDurationInSeconds,
    bool deactive,
    int resolutionFactor
): 
    chromaMatrix(chromaMatrix), 
    enhancedChromaMatrix(enhancedChromaMatrix),
    sampleRate(sampleRate),
    hopSize(hopSize),
    localMaxWindowSizeInSeconds(localMaxWindowSizeInSeconds),
    lowAmplitudeThreshold(lowAmplitudeThreshold),
    medianLengthInSeconds(medianLengthInSeconds),
    minDurationInSeconds(minDurationInSeconds),
    deactive(deactive),
    resolutionFactor(resolutionFactor)
{
    // Convert median filter window size and minimum duration from seconds to frames
    localMaxWindowSizeInFrames = secondsToFrames(localMaxWindowSizeInSeconds, sampleRate, hopSize);
    medianLengthInFrames = secondsToFrames(medianLengthInSeconds, sampleRate, hopSize);
    minDurationInFrames = secondsToFrames(minDurationInSeconds, sampleRate, hopSize);

    if (medianLengthInFrames <= 0) {
        medianLengthInFrames = 0; // bypass
    } else if ((medianLengthInFrames % 2) == 0) { 
        ++medianLengthInFrames; // Force odd 
    }

    if (this->resolutionFactor < 1) this->resolutionFactor = 1;
}

// Enhance inputChroma and write to outputChroma
void ChromaEnhancer::computeEnhancement() {
    if (deactive) {
        enhancedChromaMatrix = chromaMatrix; // bypass
        return;
    }
    convertToLogScale();
    normalizeByLocalMaximaInTime();
    dropLowAmplitudes(lowAmplitudeThreshold);
    medianTimeFilterSliding(medianLengthInFrames);
    dropShortTimeExcitations(minDurationInFrames);
    interpolateInTime(resolutionFactor);
}

// Convert chroma values to log scale 
void ChromaEnhancer::convertToLogScale() {
    size_t numFrames = chromaMatrix.size();
    if (numFrames == 0) return;
    size_t numBins = chromaMatrix[0].size();
    enhancedChromaMatrix.assign(numFrames, std::vector<float>(numBins, 0.0f));

    for (size_t frame = 0; frame < numFrames; ++frame) {
        for (size_t bin = 0; bin < numBins; ++bin) {
            float v = chromaMatrix[frame][bin];
            enhancedChromaMatrix[frame][bin] = v > eps ? std::log2f(v) : std::log2f(eps); // log scale with floor at 0
        }
    }
}

void ChromaEnhancer::normalizeByLocalMaximaInTime() {
    size_t numFrames = enhancedChromaMatrix.size();
    if (numFrames == 0) return;
    size_t numBins = enhancedChromaMatrix[0].size();

    if (localMaxWindowSizeInFrames <= 0) { // Use global maximum
        float globalMax = 0.0f;
        for (size_t frame = 0; frame < numFrames; ++frame) {
            for (size_t bin = 0; bin < numBins; ++bin) {
                globalMax = std::max(globalMax, enhancedChromaMatrix[frame][bin]);
            }
        }
        if (globalMax < std::log2f(eps) + 1.0f) return; // Avoid division by near-zero and also means chroma is essentially silent
        for (size_t frame = 0; frame < numFrames; ++frame) {
            for (size_t bin = 0; bin < numBins; ++bin) {
                float v = enhancedChromaMatrix[frame][bin];
                enhancedChromaMatrix[frame][bin] = (v - std::log2f(eps)) / (globalMax - std::log2f(eps)); // normalize to [0, 1] based on global max
            }
        }
        return;
    }

    // Find average maximum across all frames
    float averageMax = 0.0f;
    for (int frame = 0; frame < numFrames; ++frame) {
        float currentMax = 0.0f;
        for (int bin = 0; bin < numBins; ++bin) {
            currentMax = std::max(currentMax, enhancedChromaMatrix[frame][bin]);
        }
        averageMax += currentMax;
    }
    averageMax /= numFrames;

    // Use local maximum in the window [frame - localMaxWindowSizeInFrames, frame] with zero-padding at the beginning. We cap from below with averageMax.
    for (int frame = numFrames - 1; frame >= 0; --frame) {
        float localMax = averageMax; // start with average max as a floor
        for (int offset = 0; offset < localMaxWindowSizeInFrames; ++offset) {
            int idx = static_cast<int>(frame) - offset;
            if (idx < 0) break; // zero-padding at the beginning
            for (size_t bin = 0; bin < numBins; ++bin) {
                localMax = std::max(localMax, enhancedChromaMatrix[idx][bin]);
            }
        }
        if (localMax < std::log2f(eps) + 1.0f) continue; // Avoid division by near-zero and also means chroma is essentially silent
        for (int bin = 0; bin < numBins; ++bin) {
            float v = enhancedChromaMatrix[frame][bin];
            enhancedChromaMatrix[frame][bin] = (v - std::log2f(eps)) / (localMax - std::log2f(eps)); // normalize to [0, 1] based on local max
        }
    }
}

// Drop chroma values below threshold and resize to [0, 1]
void ChromaEnhancer::dropLowAmplitudes(float threshold) {
    if (threshold <= 0.0f) return; // no drop
    size_t numFrames = enhancedChromaMatrix.size();
    if (numFrames == 0) return;
    size_t numBins = enhancedChromaMatrix[0].size();

    for (size_t frame = 0; frame < numFrames; ++frame) {
        for (size_t bin = 0; bin < numBins; ++bin) {
            float v = enhancedChromaMatrix[frame][bin];
            // Thresholding
            if (v < threshold) v = 0.0f;
            else v = (v - threshold) / (1.0f - threshold);
            enhancedChromaMatrix[frame][bin] = v;
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

// Linear interpolation in time by an integer upsampling factor.
// factor = 1 leaves the matrix unchanged.
void ChromaEnhancer::interpolateInTime(int factor) {
    if (factor <= 1) return;

    size_t numFrames = enhancedChromaMatrix.size();
    if (numFrames < 2) return;
    size_t numBins = enhancedChromaMatrix[0].size();

    size_t upsampledFrames = (numFrames - 1) * static_cast<size_t>(factor) + 1;
    std::vector<std::vector<float>> out(upsampledFrames, std::vector<float>(numBins, 0.0f));

    size_t outFrame = 0;
    for (size_t t = 0; t + 1 < numFrames; ++t) {
        const std::vector<float>& a = enhancedChromaMatrix[t];
        const std::vector<float>& b = enhancedChromaMatrix[t + 1];
        for (int k = 0; k < factor; ++k) {
            float alpha = static_cast<float>(k) / static_cast<float>(factor);
            for (size_t bin = 0; bin < numBins; ++bin) {
                out[outFrame][bin] = (1.0f - alpha) * a[bin] + alpha * b[bin];
            }
            ++outFrame;
        }
    }

    out[outFrame] = enhancedChromaMatrix.back();
    enhancedChromaMatrix.swap(out);
}
