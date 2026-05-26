#define DR_WAV_IMPLEMENTATION
#define DR_MP3_IMPLEMENTATION
#define DR_FLAC_IMPLEMENTATION

#include "audioloader.h"
#include <cstring>


AudioLoader::AudioLoader(
    const char* file_path, 
    int sampleRate,
    std::vector<float>& audio_buffer
): 
    file_path(file_path), 
    sampleRate(sampleRate),
    audio_buffer(audio_buffer) 
{}

// Mix interleaved multi-channel buffer down to mono
static void mixdown_to_mono(const std::vector<float>& in, std::vector<float>& out, int channels) {
    if (channels == 1) {
        out = in;
        return;
    }
    size_t frames = in.size() / channels;
    out.resize(frames);
    float inv = 1.0f / channels;
    for (size_t i = 0; i < frames; ++i) {
        float sum = 0.0f;
        for (int ch = 0; ch < channels; ++ch)
            sum += in[i * channels + ch];
        out[i] = sum * inv;
    }
}

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

    std::vector<float> mono_buffer;
    mixdown_to_mono(temp_buffer, mono_buffer, channels);

    if (in_sr != sampleRate) {
        resample(mono_buffer, audio_buffer, in_sr, sampleRate);
    } else {
        audio_buffer = std::move(mono_buffer);
    }
}

// Simple linear interpolation resampler (mono)
void AudioLoader::resample(const std::vector<float>& in, std::vector<float>& out, int in_sr, int out_sr) {
    if (in_sr == out_sr) {
        out = in;
        return;
    }
    size_t in_frames = in.size();
    size_t out_frames = static_cast<size_t>(static_cast<double>(in_frames) * out_sr / in_sr);
    out.resize(out_frames);
    for (size_t i = 0; i < out_frames; ++i) {
        double pos = static_cast<double>(i) * in_sr / out_sr;
        size_t idx = static_cast<size_t>(pos);
        double frac = pos - idx;
        float s0 = in[std::min(idx, in_frames - 1)];
        float s1 = in[std::min(idx + 1, in_frames - 1)];
        out[i] = static_cast<float>(s0 + (s1 - s0) * frac);
    }
}


void AudioLoader::load_mp3() {
    drmp3 mp3;
    if (!drmp3_init_file(&mp3, file_path, nullptr)) {
        // TODO: Handle decoding error
        return;
    }
    int in_sr = static_cast<int>(mp3.sampleRate);
    int channels = static_cast<int>(mp3.channels);

    const drmp3_uint64 chunkFrames = 4096;
    std::vector<float> temp_buffer;
    std::vector<float> chunk(chunkFrames * channels);
    drmp3_uint64 framesRead;
    while ((framesRead = drmp3_read_pcm_frames_f32(&mp3, chunkFrames, chunk.data())) > 0) {
        temp_buffer.insert(temp_buffer.end(), chunk.begin(), chunk.begin() + framesRead * channels);
    }
    drmp3_uninit(&mp3);

    std::vector<float> mono_buffer;
    mixdown_to_mono(temp_buffer, mono_buffer, channels);

    if (in_sr != sampleRate) {
        resample(mono_buffer, audio_buffer, in_sr, sampleRate);
    } else {
        audio_buffer = std::move(mono_buffer);
    }
}

static bool ends_with(const char* str, const char* suffix) {
    size_t slen = strlen(str);
    size_t sflen = strlen(suffix);
    if (sflen > slen) return false;
    for (size_t i = 0; i < sflen; ++i) {
        char c = str[slen - sflen + i];
        if (c >= 'A' && c <= 'Z') c += 32; // tolower
        if (c != suffix[i]) return false;
    }
    return true;
}

void AudioLoader::load_flac() {
    drflac* pFlac = drflac_open_file(file_path, nullptr);
    if (!pFlac) {
        // TODO: Handle decoding error
        return;
    }
    std::vector<float> temp_buffer(static_cast<size_t>(pFlac->totalPCMFrameCount) * pFlac->channels);
    drflac_read_pcm_frames_f32(pFlac, pFlac->totalPCMFrameCount, temp_buffer.data());
    int in_sr = static_cast<int>(pFlac->sampleRate);
    int channels = static_cast<int>(pFlac->channels);
    drflac_close(pFlac);

    std::vector<float> mono_buffer;
    mixdown_to_mono(temp_buffer, mono_buffer, channels);

    if (in_sr != sampleRate) {
        resample(mono_buffer, audio_buffer, in_sr, sampleRate);
    } else {
        audio_buffer = std::move(mono_buffer);
    }
}

void AudioLoader::load() {
    if (ends_with(file_path, ".mp3")) {
        load_mp3();
    } else if (ends_with(file_path, ".flac")) {
        load_flac();
    } else if (ends_with(file_path, ".wav")) {
        load_wav();
    } else {
        audio_buffer.clear(); // Unsupported format, return empty buffer
    }
}
