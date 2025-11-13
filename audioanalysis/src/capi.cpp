#include "capi.h"
#include "audioanalyzer.h"

#include <cstring>

#if defined(__ANDROID__) || defined(__linux__)
#include "audioloader.h"
#include <vector>
#endif


#ifdef __cplusplus
extern "C" {
#endif

CAudioAnalysisResult* analyze_audio_buffer(const float* buffer, int buffer_length){
    // Analyze audio buffer
    AudioAnalysisResult result;
    AudioAnalyzer analyzer(buffer, buffer_length, result); 
    analyzer.analyze();

    // Convert to C compatible struct
    CAudioAnalysisResult* c_result = new CAudioAnalysisResult;
    c_result->duration = result.duration;
    c_result->key = new char[result.musicalKeys.empty() ? 1 : result.musicalKeys[0].size() + 1];
    if (!result.musicalKeys.empty()) {
        std::strcpy(c_result->key, result.musicalKeys[0].c_str());
    } else {
        c_result->key[0] = '\0';
    }
    // Flatten chromaMatrix via chromaMatrix[frame][bin] = chromagram[bin * chroma_n_frames + frame]
    c_result->chroma_n_frames = result.chromaMatrix.size();
    c_result->chroma_n_bins = result.chromaMatrix[0].size();
    c_result->chromagram = new float[c_result->chroma_n_frames * c_result->chroma_n_bins];

    for (int bin = 0; bin < c_result->chroma_n_bins; ++bin) {
        for (int frame = 0; frame < c_result->chroma_n_frames; ++frame) {
            c_result->chromagram[bin * c_result->chroma_n_frames + frame] = result.chromaMatrix[frame][bin];
        }
    }
    return c_result;
}

#if defined(__ANDROID__) || defined(__linux__)
CAudioAnalysisResult* analyze_audio_file(const char* file_path) {
    std::vector<float> audio_buffer(0);
    AudioLoader loader(file_path, audio_buffer);
    loader.load();
    return analyze_audio_buffer(audio_buffer.data(), audio_buffer.size());
}
#endif

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