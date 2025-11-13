#define DR_WAV_IMPLEMENTATION

#include "audioloader.h"


AudioLoader::AudioLoader(const char* file_path, std::vector<float>& audio_buffer)
    : file_path(file_path), audio_buffer(audio_buffer) {}

void AudioLoader::load_wav() {
    drwav wav;
    if (!drwav_init_file(&wav, file_path, nullptr)) {
        // TODO: Handle decoding error
    }
    audio_buffer.resize(wav.totalPCMFrameCount * wav.channels);
    drwav_read_pcm_frames_f32(&wav, wav.totalPCMFrameCount, audio_buffer.data());
    drwav_uninit(&wav);
}

void AudioLoader::load() {
    // TODO: Decide which file format to try
    load_wav();
}
