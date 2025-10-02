#pragma once
#include <vector>
#include <cstdint>

// Cuts an audio buffer into frames. Each frame is windowed using a Hanning function. An empty frame signals end of audio buffer.
class FrameCutter {
public:
    FrameCutter(
        const std::vector<float>& audioBuffer, // Input: audio buffer 
        std::vector<float>& frameBuffer // Output: current frame buffer
    );

    FrameCutter(
        const float* audio_buffer, // Input: audio buffer (float array)
        int audio_buffer_length, // Input: corresponding length of audio buffer
        std::vector<float>& frameBuffer // Output: current frame buffer
    );

    // Parameters
    int sampleRate = 44100; // samplerate of audio buffer, in Hz
    int frameSize = 8192; // size of each frame
    int hopSize = 1024; // hop size to next frame

    void computeNextFrame();

private:
    const std::vector<float>* audioVector = nullptr; // Input: audio buffer (vector<float>)
    const float* audioArray = nullptr; // Input: audio buffer (float array)
    int64_t audioSize; // size of audio buffer
    int64_t currentPosition = 0; // current position in audio buffer
    std::vector<float>& frame; // Output: current frame buffer
    std::vector<float> hanningWindow; // Precomputed Hanning window
    
    void initialize();
};