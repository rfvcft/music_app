#pragma once
#include <vector>

// Cuts an audio buffer into frames. Each frame is windowed using a Hanning function. An empty frame signals end of audio buffer.
class FrameCutter {
public:
    FrameCutter(
        const float* audio_buffer, // Input: audio buffer (float array)
        int audio_buffer_length, // Input: corresponding length of audio buffer
        std::vector<float>& frame, // Output: current frame
        int frameSize, // Parameter: size of each frame. Must be a power of 2. (Default: 8192) 
        int hopSize, // Parameter: hop size to next frame. (Default: 1024)
        const std::string& currentPositionAt // Parameter: "start", "center" or "end" - defines whether current position refers to start, center of end of frame. (Default: "center")
    );

    FrameCutter(
        const std::vector<float>& audioBuffer,
        std::vector<float>& frame,
        int frameSize,
        int hopSize,
        const std::string& currentPositionAt
    ) : FrameCutter(audioBuffer.data(), static_cast<int>(audioBuffer.size()), frame, frameSize, hopSize, currentPositionAt) {}

    void computeNextFrame(); // chop the next frame from the audio buffer and store it in the output frame buffer. If end of audio buffer is reached, output frame will be empty.
    int getExpectedNumberOfFrames();  // get expected total number of frames

private:
    const float* audio_buffer;
    int audio_buffer_length;
    std::vector<float>& frame;
    int frameSize; 
    int hopSize; 
    std::string currentPositionAt; 

    int currentPosition = 0; // current position in audio buffer
    std::vector<float> hanningWindow;
};