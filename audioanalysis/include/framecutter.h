#pragma once
#include <vector>

// Cuts an audio buffer into frames. Each frame is windowed using a Hanning function. An empty frame signals end of audio buffer.
class FrameCutter {
public:
    FrameCutter(
        const float* audio_buffer, // Input: audio buffer (float array)
        int audio_buffer_length, // Input: corresponding length of audio buffer
        std::vector<float>& frameBuffer // Output: current frame buffer
    );

    FrameCutter(
        const std::vector<float>& audio_buffer, // Input: audio buffer (float vector)
        std::vector<float>& frameBuffer // Output: current frame buffer
    ) : FrameCutter(audio_buffer.data(), static_cast<int>(audio_buffer.size()), frameBuffer) {}

    // Parameters
    int frameSize = 8192; // size of each frame. MUST BE A POWER OF 2 FOR FFT
    int hopSize = 1024; // hop size to next frame
    bool zeroCentered = true; // if true, frames are centered around the hop position (with zero-padding at start/end)
    std::string currentPositionAt = "start"; // "start", "center" or "end" - defines whether current position refers to start, center of end of frame

    int numFrames; // expected total number of frames

    void computeNextFrame();

private:
    const float* audioBuffer; 
    int audioBufferLength; 
    int currentPosition = 0; // current position in audio buffer
    std::vector<float>& frame; 
    std::vector<float> hanningWindow; 
};