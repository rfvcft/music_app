#ifndef AUDIO_BUFFER_LOADER_H
#define AUDIO_BUFFER_LOADER_H

#ifdef __cplusplus
extern "C" {
#endif

// Loads audio file at filePath (.wav, .m4a, .mp3), converts to mono, 44.1kHz, float32, and returns a malloc'd buffer. Length is set in outLength.
float* loadAudioBufferFromFile(const char* filePath, int* outLength);

// Frees the buffer allocated by loadAudioBufferFromFile
void freeAudioBuffer(float* buffer);

#ifdef __cplusplus
}
#endif

#endif // AUDIO_BUFFER_LOADER_H
