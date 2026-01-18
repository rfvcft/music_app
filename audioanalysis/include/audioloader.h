#pragma once

#include <vector>

#include "../third_party/dr_libs/dr_wav.h"

class AudioLoader {

public:
    AudioLoader(
        const char* file_path,              // Input: Path to audio file
        std::vector<float>& audio_buffer    // Output: Decoded audio buffer
    );

    // Parameters
    int sampleRate = 44100; // Desired sample rate for output audio buffer

    void load();

private:
    const char* const file_path;
    std::vector<float>& audio_buffer;
    void load_wav();
    void resample(const std::vector<float>& in, std::vector<float>& out, int in_sr, int out_sr, int channels);
};
