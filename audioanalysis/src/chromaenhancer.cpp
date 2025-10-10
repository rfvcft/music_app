#include "chromaenhancer.h"
#include <algorithm>
#include <cmath>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

ChromaEnhancer::ChromaEnhancer(const std::vector<std::vector<float>>& inputChroma, std::vector<std::vector<float>>& outputChroma)
                               : chromaMatrix(inputChroma), enhancedChromaMatrix(outputChroma){}

void ChromaEnhancer::computeEnhancement() {
    copyMatrix();
    convertToLogScale();
    dropLowAmplitudes();
    dropShortTimeExcitations();
    //normalizeChromaFrames();
}

void ChromaEnhancer::copyMatrix() {
    size_t numFrames = chromaMatrix.size();
    if (numFrames == 0) return;
    size_t numBins = chromaMatrix[0].size();
    enhancedChromaMatrix.resize(numFrames, std::vector<float>(numBins, 0.0f));
    for (size_t t = 0; t < numFrames; ++t) {
        for (size_t k = 0; k < numBins; ++k) {
            enhancedChromaMatrix[t][k] = chromaMatrix[t][k];
        }
    }
}

void ChromaEnhancer::convertToLogScale() {
    float eps = 1e-12f; // small constant to avoid log(0)
    size_t numFrames = chromaMatrix.size();
    if (numFrames == 0) return;
    size_t numBins = chromaMatrix[0].size();
    enhancedChromaMatrix.resize(numFrames, std::vector<float>(numBins, 0.0f));

    // Find global max
    float maxChroma = eps;
    for (const auto& frame : chromaMatrix)
        for (float v : frame)
            if (v > maxChroma) maxChroma = v;

    // Enhance each value
    for (size_t t = 0; t < numFrames; ++t) {
        for (size_t k = 0; k < numBins; ++k) {
            float v = chromaMatrix[t][k];
            // Log scale
            if (v < eps) v = 0.0f;
            else v = (std::log(v) - std::log(eps)) / (std::log(maxChroma) - std::log(eps));
            enhancedChromaMatrix[t][k] = v;
        }
    }
}

void ChromaEnhancer::dropLowAmplitudes() {
    size_t numFrames = chromaMatrix.size();
    if (numFrames == 0) return;
    size_t numBins = chromaMatrix[0].size();

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

void ChromaEnhancer::dropShortTimeExcitations() {
    size_t numFrames = chromaMatrix.size();
    if (numFrames == 0) return;
    size_t numBins = chromaMatrix[0].size();

    int minDurationFrames = 10; // Minimum duration in frames to keep a chroma activation
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



void ChromaEnhancer::normalizeChromaFrames() {
    size_t numFrames = enhancedChromaMatrix.size();
    if (numFrames == 0) return;
    size_t numBins = enhancedChromaMatrix[0].size();

    for (size_t t = 0; t < numFrames; ++t) {
        float maxVal = *std::max_element(enhancedChromaMatrix[t].begin(), enhancedChromaMatrix[t].end());
        if (maxVal > 0.0f) {
            for (size_t k = 0; k < numBins; ++k) {
                enhancedChromaMatrix[t][k] /= maxVal;
            }
        }
    }
}