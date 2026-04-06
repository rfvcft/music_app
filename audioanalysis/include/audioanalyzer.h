#pragma once
#include <vector>
#include <string>

struct AudioAnalysisResult {
    std::vector<std::vector<float>> chromaMatrix;
    std::vector<std::string> musicalKeys;
    float duration; // in seconds
};

// Analyzes an audio buffer and writes results to AudioAnalysisResult struct
class AudioAnalyzer {
public: 
    AudioAnalyzer(
        const float* audio_buffer, // Input: audio buffer (float array)
        int audio_buffer_length, // Input: corresponding length of audio buffer
        int sampleRate, // Parameter: sample rate of the audio signal, in Hz (Default: 44100)
        AudioAnalysisResult& result // Output: analysis result
    );

    AudioAnalyzer(
        const std::vector<float>& audioBuffer, // Input: audio buffer (float vector)
        int sampleRate, // Parameter: sample rate of the audio signal, in Hz (Default: 44100)
        AudioAnalysisResult& result // Output: analysis result
    ): 
    AudioAnalyzer(
        audioBuffer.data(), 
        static_cast<int>(audioBuffer.size()), 
        sampleRate,
        result
    ) {}

    void analyze();

private:
    const float* audio_buffer; 
    int audio_buffer_length;
    int sampleRate;
    AudioAnalysisResult& result;
};