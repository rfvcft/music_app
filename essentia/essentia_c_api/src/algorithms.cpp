#include <essentia/algorithmfactory.h>
#include <essentia/essentia.h>

#include <iostream>
#include <vector>
#include <fstream>
#include <string>
#include "algorithms.h"


// IMPORTANT: All audio buffers and processing in this file assume a sampling rate of 44.1kHz (the standard sampling rate in Essentia).
// Ensure your input audio is resampled to 44 100 Hz before using these functions.

// Loads audio buffer from .raw file
std::vector<essentia::Real> loadAudioBufferFromFile(const std::string& filePath) {
    std::ifstream inFile(filePath, std::ios::binary | std::ios::ate);
    if (!inFile) {
        throw std::runtime_error("Failed to open file for reading: " + filePath);
    }

    std::streamsize fileSize = inFile.tellg();
    inFile.seekg(0, std::ios::beg);

    if (fileSize % sizeof(float) != 0) {
        throw std::runtime_error("Invalid file size (not aligned to float): " + filePath);
    }

    std::vector<float> buffer(fileSize / sizeof(float));
    if (!inFile.read(reinterpret_cast<char*>(buffer.data()), fileSize)) {
        throw std::runtime_error("Failed to read data from file: " + filePath);
    }
    return buffer;
}

// Converts a float* buffer [buffer] of length [buffer_length] to a std::vector<essentia::Real>
std::vector<essentia::Real> audioBufferToVector(const float* buffer, int buffer_length) {
    if (!buffer || buffer_length <= 0) return {};
    return std::vector<essentia::Real>(buffer, buffer + buffer_length);
}


// Compute duration from audio buffer, assuming samplingrate 44.1kHz
float computeDuration(const std::vector<essentia::Real>& audio){
    return audio.size() / 44100.0f;
}

// Compute harmonic pitch class profile (HPCP) from audio buffer using Essentia
std::vector<std::vector<essentia::Real>> computeHPCP(const std::vector<essentia::Real>& audio){
    using namespace essentia::standard;

    AlgorithmFactory& factory = AlgorithmFactory::instance();

    Algorithm* frameCutter = factory.create("FrameCutter",
        "frameSize", 2048,
        "hopSize", 512,
        "startFromZero", true);
    std::vector<essentia::Real> frame;
    frameCutter->input("signal").set(audio);
    frameCutter->output("frame").set(frame);

    Algorithm* window = factory.create("Windowing", "type", "hann");
    std::vector<essentia::Real> windowedFrame;
    window->input("frame").set(frame);
    window->output("frame").set(windowedFrame);

    Algorithm* spectrum = factory.create("Spectrum");
    std::vector<essentia::Real> spectrumFrame;
    spectrum->input("frame").set(windowedFrame);
    spectrum->output("spectrum").set(spectrumFrame);

    Algorithm* peaks = factory.create("SpectralPeaks",
        "maxPeaks", 100,
        "orderBy", "magnitude",
        "magnitudeThreshold", 0.0001);
    std::vector<essentia::Real> frequencies, magnitudes;
    peaks->input("spectrum").set(spectrumFrame);
    peaks->output("frequencies").set(frequencies);
    peaks->output("magnitudes").set(magnitudes);

    Algorithm* hpcp = factory.create("HPCP",
        "size", 12,
        "referenceFrequency", 440.0,
        "bandPreset", false,
        "minFrequency", 100.0,
        "maxFrequency", 5000.0,
        "nonLinear", false,
        "normalized", "none",
        "windowSize", 1.0);
    std::vector<essentia::Real> hpcpFrame;
    hpcp->input("frequencies").set(frequencies);
    hpcp->input("magnitudes").set(magnitudes);
    hpcp->output("hpcp").set(hpcpFrame);

    std::vector<std::vector<essentia::Real>> hpcpMatrix;
    while (true) {
        frameCutter->compute();
        if (frame.empty()) break;
        window->compute();
        spectrum->compute();
        peaks->compute();
        hpcp->compute();
        std::rotate(hpcpFrame.begin(), hpcpFrame.begin() + 3, hpcpFrame.end());
        hpcpMatrix.push_back(hpcpFrame);
    }

    delete frameCutter;
    delete window;
    delete spectrum;
    delete peaks;
    delete hpcp;

    size_t frames = hpcpMatrix.size();
    size_t bins = hpcpMatrix[0].size();
    std::vector<std::vector<essentia::Real>> transposed(bins, std::vector<essentia::Real>(frames));
    for (size_t i = 0; i < bins; i++)
        for (size_t j = 0; j < frames; j++)
            transposed[i][j] = hpcpMatrix[j][i];

    return transposed;
}

// Enhance HPCP using basic filters
void enhance(std::vector<std::vector<essentia::Real>>& matrix){
    using essentia::Real;

    float max_val = -std::numeric_limits<Real>::infinity();
    for (const auto& row : matrix)
        for (float val : row)
            max_val = std::max(max_val, val);
    if (max_val > 0.0f) {
        for (auto& row : matrix)
            for (Real& val : row)
                val /= max_val;
    }

    for (auto& row : matrix)
        for (Real& val : row)
            val = std::log(1000.0f * val + 1.0f);

    Real global_threshold = 0.2f * std::log(1000.0f * 1.0f + 1.0f);
    for (auto& row : matrix)
        for (Real& val : row)
            if (val < global_threshold)
                val = 0.0f;

    int rows = matrix.size(), cols = matrix[0].size();
    std::vector<Real> col_max(cols, 0.0f);
    for (int j = 0; j < cols; ++j)
        for (int i = 0; i < rows; ++i)
            col_max[j] = std::max(col_max[j], matrix[i][j]);

    Real column_threshold = 0.2f * std::log(1000.0f * 1.0f + 1.0f);
    for (int j = 0; j < cols; ++j) {
        if (col_max[j] < column_threshold)
            for (int i = 0; i < rows; ++i)
                matrix[i][j] = 0.0f;
        else
            for (int i = 0; i < rows; ++i)
                matrix[i][j] /= col_max[j];
    }

    int filter_width = 32, half = filter_width / 2;
    std::vector<std::vector<Real>> smoothed = matrix;
    for (int i = 0; i < rows; ++i)
        for (int j = 0; j < cols; ++j) {
            std::vector<Real> window;
            for (int k = -half; k <= half; ++k) {
                int idx = j + k;
                if (idx >= 0 && idx < cols)
                    window.push_back(matrix[i][idx]);
            }
            std::nth_element(window.begin(), window.begin() + window.size() / 2, window.end());
            smoothed[i][j] = window[window.size() / 2];
        }
    matrix = smoothed;
}


// Computes key of audio buffer 
std::string computeKey(const std::vector<essentia::Real>& audio){
    using namespace essentia::standard;

    AlgorithmFactory& factory = AlgorithmFactory::instance();
    Algorithm* keyExtractor = factory.create("KeyExtractor");

    std::string key, scale;
    essentia::Real strength;

    keyExtractor->input("audio").set(audio);
    keyExtractor->output("key").set(key);
    keyExtractor->output("scale").set(scale);
    keyExtractor->output("strength").set(strength);
    keyExtractor->compute();
    delete keyExtractor;

    return key + " " + scale;
}

