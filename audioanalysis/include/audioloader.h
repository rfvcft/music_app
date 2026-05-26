#pragma once

#include <string>
#include <vector>

#include "../third_party/dr_libs/dr_wav.h"
#include "../third_party/dr_libs/dr_mp3.h"
#include "../third_party/dr_libs/dr_flac.h"

// Loads audio file (.wav, .mp3, .flac) into a float buffer at the desired sample rate
class AudioLoader {

public:
    AudioLoader(
        const char* file_path,              // Input: Path to audio file (C string)
        int sampleRate,                     // Parameter: Desired sample rate for output audio buffer
        std::vector<float>& audio_buffer    // Output: Decoded audio buffer
    );

    AudioLoader(
        const std::string& file_path,       // Input: Path to audio file (std::string)
        int sampleRate,                     // Parameter: Desired sample rate for output audio buffer
        std::vector<float>& audio_buffer    // Output: Decoded audio buffer
    ) : AudioLoader(file_path.c_str(), sampleRate, audio_buffer) {}

    void load();

private:
    const char* const file_path;
    int sampleRate;
    std::vector<float>& audio_buffer;
    void load_wav();
    void load_mp3();
    void load_flac();
    void resample(const std::vector<float>& in, std::vector<float>& out, int in_sr, int out_sr);
};
