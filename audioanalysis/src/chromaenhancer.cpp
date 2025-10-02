#include "chromaenhancer.h"
#include <algorithm>
#include <cmath>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

ChromaEnhancer::ChromaEnhancer(const std::vector<std::vector<float>>& inputChroma, std::vector<std::vector<float>>& outputChroma)
                               : chromaMatrix(inputChroma), enhancedChromaMatrix(outputChroma){}

void ChromaEnhancer::computeEnhancement() {
    convertToLogScale();
    dropNoise();
    if (enhanceSmooth) enhanceSmoothly();
    if (normalize) normalizeChromaFrames();
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

void ChromaEnhancer::dropNoise() {
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

void ChromaEnhancer::enhanceSmoothly() {
    size_t numFrames = chromaMatrix.size();
    if (numFrames == 0) return;
    size_t numBins = chromaMatrix[0].size();

    for (size_t t = 0; t < numFrames; ++t) {
        for (size_t k = 0; k < numBins; ++k) {
            float v = enhancedChromaMatrix[t][k];
            // Other thresholding
            v = smoothEnhancer(v);
            enhancedChromaMatrix[t][k] = v;
        }
    }
}

// Smooth function from f(0) = f(a) = 0 to f(b) = f(1) = 1
float ChromaEnhancer::smoothEnhancer(float x) {
    float a = 0.0f;
    float b = 0.6f;
    if (x < a) return 0.0f;
    else if (x > b) return 1.0f;
    else return 0.5f *(1.0f - std::cos(M_PI * (x - a) / (b - a)));
}



void ChromaEnhancer::normalizeChromaFrames() {
    size_t numFrames = enhancedChromaMatrix.size();
    if (numFrames == 0) return;
    size_t numBins = enhancedChromaMatrix[0].size();

    float sumTotal = 0.0f;
    for (size_t t = 0; t < numFrames; ++t) {
        float frameSum = 0.0f;
        for (size_t k = 0; k < numBins; ++k) {
            frameSum += enhancedChromaMatrix[t][k];
        }
        sumTotal += frameSum;
    }
    float avgFrameSum = sumTotal / static_cast<float>(numFrames);
    // avgFrameSum now holds the average sum of chroma values per frame
    float percentage = 0.2f;
    float normalizeThreshold = percentage * avgFrameSum;
    for (size_t t = 0; t < numFrames; ++t) {
        float frameSum = 0.0f;
        for (size_t k = 0; k < numBins; ++k) {
            frameSum += enhancedChromaMatrix[t][k];
        }
        if (frameSum > normalizeThreshold && frameSum > 0.0f) {
            float maxVal = *std::max_element(enhancedChromaMatrix[t].begin(), enhancedChromaMatrix[t].end());
            if (maxVal > 0.0f) {
                for (size_t k = 0; k < numBins; ++k) {
                    enhancedChromaMatrix[t][k] /= maxVal;
                }
            }
        }
    }
}