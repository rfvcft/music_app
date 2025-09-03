#ifndef AUDIO_BUFFER_LOADER_H
#define AUDIO_BUFFER_LOADER_H

#ifdef __cplusplus
extern "C" {
#endif

// Loads an audio file at filePath (.m4a), converts to mono, 44.1kHz, float32, and returns a malloc'd buffer. Length is set in outLength.
float* loadAudioBufferFromM4A(const char* filePath, int* outLength);

// Frees the buffer allocated by loadAudioBufferFromM4A
void freeAudioBuffer(float* buffer);

#ifdef __cplusplus
}
#endif

#endif // AUDIO_BUFFER_LOADER_H
