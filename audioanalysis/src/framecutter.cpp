#include "framecutter.h"
#include <algorithm>
#include <cmath>
#include <cstring> // for std::memcpy

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif


FrameCutter::FrameCutter(const float* audio_buffer, int audio_buffer_length, std::vector<float>& frameBuffer)
    : audioBuffer(audio_buffer), audioBufferLength(audio_buffer_length), frame(frameBuffer), hanningWindow(frameSize) {

    // Calculate expected number of frames
    numFrames = static_cast<int>(std::ceil(static_cast<float>(audioBufferLength) / hopSize));

    // Initialize output frame buffer
    frame.resize(frameSize, 0.0f); 

    // Precompute Hanning window
    hanningWindow.resize(frameSize);
    for (int n = 0; n < frameSize; ++n) {
        hanningWindow[n] = 0.5f * (1.0f - std::cos(2.0f * M_PI * n / (frameSize - 1)));
    }
}

// Cuts the next frame from the audio buffer
void FrameCutter::computeNextFrame() {
    // If current position is past the end of the audio buffer, return empty frame
    if (currentPosition >= audioBufferLength) {
        frame.clear();
        return;
    }

    // Compute start and end positions of frame
    int frameStart;
    int frameEnd;
    if (currentPositionAt == "center") {
        frameStart = currentPosition - frameSize / 2;
        frameEnd = currentPosition + frameSize / 2;
    } else if (currentPositionAt == "end") {
        frameStart = currentPosition - frameSize;
        frameEnd = currentPosition;
    } else if (currentPositionAt == "start") {
        frameStart = currentPosition;
        frameEnd = frameStart + frameSize;
    } else {
        // Shoudn't happen
    }

    // Fill frame with zeros
    std::fill(frame.begin(), frame.end(), 0.0f);

    // Compute valid region in input and output
    int inputStart = std::max(frameStart, 0);
    int inputEnd = std::min(frameEnd, audioBufferLength);
    int outputStart = std::max(0, -frameStart);
    int validSamples = inputEnd - inputStart;

    if (validSamples > 0) {
        std::memcpy(frame.data() + outputStart, audioBuffer + inputStart, static_cast<size_t>(validSamples) * sizeof(float));
    }

    currentPosition += hopSize;

    // Apply Hanning window
    for (int n = 0; n < frameSize; ++n) {
        frame[n] *= hanningWindow[n];
    }
}

