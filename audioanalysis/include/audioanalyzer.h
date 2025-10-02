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
        const std::vector<float>& audioBuffer, // Input: audio buffer
        AudioAnalysisResult& analysisResult // Output: analysis result
    );

    AudioAnalyzer(
        const float* audio_buffer, // Input: audio buffer (float array)
        int audio_buffer_length, // Input: corresponding length of audio buffer
        AudioAnalysisResult& analysisResult // Output: analysis result
    );

    // Parameters
    int sampleRate = 44100; // samplerate of audio buffer, in Hz

    void analyze();

private:
    const std::vector<float>* audioVector = nullptr; // Input: audio buffer (vector<float>)
    const float* audioArray = nullptr; // Input: audio buffer (float array)
    int64_t audioSize; // size of audio buffer
    AudioAnalysisResult& result; // Output: analysis result
};