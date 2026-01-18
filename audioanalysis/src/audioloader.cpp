#define DR_WAV_IMPLEMENTATION

#include "audioloader.h"


AudioLoader::AudioLoader(const char* file_path, std::vector<float>& audio_buffer)
    : file_path(file_path), audio_buffer(audio_buffer) {}

void AudioLoader::load_wav() {
    drwav wav;
    if (!drwav_init_file(&wav, file_path, nullptr)) {
        // TODO: Handle decoding error
        return;
    }
    std::vector<float> temp_buffer(wav.totalPCMFrameCount * wav.channels);
    drwav_read_pcm_frames_f32(&wav, wav.totalPCMFrameCount, temp_buffer.data());
    int in_sr = wav.sampleRate;
    int channels = wav.channels;
    drwav_uninit(&wav);

    if (in_sr != sampleRate) {
        resample(temp_buffer, audio_buffer, in_sr, sampleRate, channels);
    } else {
        audio_buffer = std::move(temp_buffer);
    }
}

// Simple linear interpolation resampler (per channel)
void AudioLoader::resample(const std::vector<float>& in, std::vector<float>& out, int in_sr, int out_sr, int channels) {
    if (in_sr == out_sr) {
        out = in;
        return;
    }
    size_t in_frames = in.size() / channels;
    size_t out_frames = static_cast<size_t>(static_cast<double>(in_frames) * out_sr / in_sr);
    out.resize(out_frames * channels);
    for (int ch = 0; ch < channels; ++ch) {
        for (size_t i = 0; i < out_frames; ++i) {
            double pos = static_cast<double>(i) * in_sr / out_sr;
            size_t idx = static_cast<size_t>(pos);
            double frac = pos - idx;
            float s0 = in[channels * std::min(idx, in_frames - 1) + ch];
            float s1 = in[channels * std::min(idx + 1, in_frames - 1) + ch];
            out[channels * i + ch] = static_cast<float>(s0 + (s1 - s0) * frac);
        }
    }
}


void AudioLoader::load() {
    // TODO: Decide which file format to try
    load_wav();
}
