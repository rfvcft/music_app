#include "framecutter.h"
#include <stdexcept>
#include <cmath>
#include <cstring> // for std::memcpy

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

FrameCutter::FrameCutter(const std::vector<float>& audioBuffer, std::vector<float>& frameBuffer)
    : audioVector(&audioBuffer), audioArray(nullptr), audioSize(audioBuffer.size()), frame(frameBuffer), hanningWindow(frameSize) {
    initialize();
}
    
FrameCutter::FrameCutter(const float* audio_buffer, int audio_buffer_length, std::vector<float>& frameBuffer)
    : audioVector(nullptr), audioArray(audio_buffer), audioSize(audio_buffer_length), frame(frameBuffer), hanningWindow(frameSize) {
    initialize();
}

void FrameCutter::initialize() {
    // Check that frameSize, hopSize, and sampleRate are all powers of 2
    auto isPowerOf2 = [](int x) { return x > 0 && (x & (x - 1)) == 0; };
    if (!isPowerOf2(frameSize)) throw std::invalid_argument("frameSize must be a power of 2");
    if (!isPowerOf2(hopSize)) throw std::invalid_argument("hopSize must be a power of 2");

    frame.resize(frameSize, 0.0f); 

    // Precompute Hanning window
    hanningWindow.resize(frameSize);
    for (int n = 0; n < frameSize; ++n) {
        hanningWindow[n] = 0.5f * (1.0f - std::cos(2.0f * M_PI * n / (frameSize - 1)));
    }
}

void FrameCutter::computeNextFrame() {
    int64_t frameStart = currentPosition;
    int64_t frameEnd = frameStart + frameSize;

    if (frameStart >= audioSize) {
        frame.clear();
        return;
    }

    int64_t validSamples = std::min(frameEnd, audioSize) - frameStart;
    if (validSamples > 0) {
        if (audioVector) {
        std::memcpy(frame.data(), audioVector->data() + frameStart, validSamples * sizeof(float));
        } else if (audioArray) {
        std::memcpy(frame.data(), audioArray + frameStart, validSamples * sizeof(float));
        } else {
            throw std::runtime_error("No valid audio buffer provided.");
        }
    }
    if (validSamples < frameSize) {
        std::fill(frame.begin() + validSamples, frame.end(), 0.0f);
    }

    currentPosition += hopSize;
    // Apply Hanning window
    for (int n = 0; n < frameSize; ++n) {
        frame[n] *= hanningWindow[n];
    }
}

