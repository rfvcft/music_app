#include "capi.h"
#include "audioanalyzer.h"
#include "audioloader.h"

#include <cstring>
#include <vector>


#ifdef __cplusplus
extern "C" {
#endif

CAudioAnalysisResult* analyze_audio_buffer(const float* buffer, int buffer_length){
    int sampleRate = 44100; // sample rate in Hz

    // Analyze audio buffer
    AudioAnalysisResult result;
    AudioAnalyzer analyzer(buffer, buffer_length, sampleRate, result); 
    analyzer.analyze();

    // Convert to C compatible struct
    CAudioAnalysisResult* c_result = new CAudioAnalysisResult;
    c_result->duration = result.duration;
    // Handle musicalKeys safely
    if (!result.musicalKeys.empty() && !result.musicalKeys[0].empty()) {
        c_result->key = new char[result.musicalKeys[0].size() + 1];
        std::strcpy(c_result->key, result.musicalKeys[0].c_str());
    } else {
        c_result->key = new char[1];
        c_result->key[0] = '\0';
    }

    // Handle chromaMatrix safely
    if (!result.chromaMatrix.empty() && !result.chromaMatrix[0].empty()) {
        c_result->chroma_n_frames = result.chromaMatrix.size();
        c_result->chroma_n_bins = result.chromaMatrix[0].size();
        c_result->chromagram = new float[c_result->chroma_n_frames * c_result->chroma_n_bins];
        for (int bin = 0; bin < c_result->chroma_n_bins; ++bin) {
            for (int frame = 0; frame < c_result->chroma_n_frames; ++frame) {
                c_result->chromagram[bin * c_result->chroma_n_frames + frame] = result.chromaMatrix[frame][bin]; // Flatten according to chromaMatrix[frame][bin] = chromagram[bin * chroma_n_frames + frame]
            }
        }
    } else {
        c_result->chroma_n_frames = 0;
        c_result->chroma_n_bins = 0;
        c_result->chromagram = nullptr;
    }
    return c_result;
}

CAudioAnalysisResult* analyze_audio_file(const char* file_path) {
    int sampleRate = 44100; // sample rate in Hz

    std::vector<float> audio_buffer;
    AudioLoader loader(file_path, sampleRate, audio_buffer);
    loader.load();
    return analyze_audio_buffer(audio_buffer.data(), audio_buffer.size());
}

void delete_analysis_result(CAudioAnalysisResult* result) {
    if (result) {
        delete[] result->key;
        delete[] result->chromagram;
        delete result;
    }
}

#ifdef __cplusplus
}
#endif