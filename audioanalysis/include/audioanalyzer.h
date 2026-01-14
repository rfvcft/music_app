#pragma once
#include <vector>
#include <string>

struct AudioAnalysisResult {
    std::vector<std::vector<float>> chromaMatrix;
    std::vector<std::string> musicalKeys;
    float duration; // in seconds
};

// Analyzes an audio buffer and writes results to AudioAnalysisResult struct. Assumes sampleRate 44100.
class AudioAnalyzer {
public: 
    AudioAnalyzer(
        const float* audio_buffer, // Input: audio buffer (float array)
        int audio_buffer_length, // Input: corresponding length of audio buffer
        AudioAnalysisResult& analysisResult // Output: analysis result
    );

    AudioAnalyzer(
        const std::vector<float>& audio_buffer, // Input: audio buffer (float vector)
        AudioAnalysisResult& analysisResult // Output: analysis result
    ) : AudioAnalyzer(audio_buffer.data(), static_cast<int>(audio_buffer.size()), analysisResult) {}

    // Parameters
    int sampleRate = 44100; // samplerate of audio buffer, in Hz

    void analyze();

private:
    const float* audioBuffer; 
    int audioBufferLength;
    AudioAnalysisResult& result;
};