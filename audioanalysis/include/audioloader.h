#pragma once

#include <vector>

#include "../third_party/dr_libs/dr_wav.h"
#include "../third_party/dr_libs/dr_mp3.h"

class AudioLoader {

public:
    AudioLoader(
        const char* file_path,              // Input: Path to audio file
        int sampleRate,                     // Parameter: Desired sample rate for output audio buffer
        std::vector<float>& audio_buffer    // Output: Decoded audio buffer
    );

    void load();

private:
    const char* const file_path;
    int sampleRate;
    std::vector<float>& audio_buffer;
    void load_wav();
    void load_mp3();
    void resample(const std::vector<float>& in, std::vector<float>& out, int in_sr, int out_sr);
};
