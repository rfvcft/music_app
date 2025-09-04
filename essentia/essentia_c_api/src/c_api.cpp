#include "essentia/essentia.h"
#include "c_api.h"
#include "algorithms.h"

#include <iostream>

// Analyze audio buffer using Essentia. Returns results in custom struct (see header for definition)
EssentiaAnalysisResult* essentia_analyze_buffer(const float* buffer, int buffer_length){
    EssentiaAnalysisResult* result = new EssentiaAnalysisResult;

    // Essentia analysis
    essentia::init();
    std::vector<essentia::Real> audio = audioBufferToVector(buffer, buffer_length); // convert float * buffer to vector buffer
    std::vector<std::vector<essentia::Real>> chroma = computeHPCP(audio); // compute chromagram 
    enhance(chroma); // enhance chromagram visuals
    std::string keyStr = computeKey(audio); // compute musical key
    float duration = computeDuration(audio); // compute duration. Assumes 44100Hz sampling rate
    essentia::shutdown();

    // Write results
    result->duration = duration;
    result->key = new char[keyStr.size() + 1];
    std::copy(keyStr.c_str(), keyStr.c_str() + keyStr.size() + 1, result->key);
    // Handle empty chroma result
    if (chroma.empty() || chroma[0].empty()) {
        result->chromagram = nullptr;
        result->chroma_n_frames = 0;
        result->chroma_n_bins = 0;
    } else {
        // Flatten chromagram to 1D array
        result->chroma_n_bins = static_cast<int>(chroma.size());
        result->chroma_n_frames = static_cast<int>(chroma[0].size());
        result->chromagram = new float[result->chroma_n_bins * result->chroma_n_frames];
        for (size_t bin = 0; bin < chroma.size(); ++bin) {
            for (size_t frame = 0; frame < chroma[bin].size(); ++frame) {
                result->chromagram[bin * chroma[bin].size() + frame] = chroma[bin][frame];
            }
        }
    }

    // Logging
    std::cout << "C++ LOG: " << std::endl;
    std::cout << "Pitch class C: ";
    for (int i = 0; i < chroma[0].size(); i++){
        std::cout << chroma[0][i];
    }
    std::cout << std::endl;
    std::cout << "float * buffer length: " << buffer_length << std::endl;
    std::cout << "buffer length divided by 44100 sr: " << buffer_length / 44100.0 << " seconds" << std::endl;
    std::cout << "vector buffer size: " << audio.size() << std::endl;
    std::cout << "Duration: " << result->duration << " seconds" << std::endl;
    std::cout << "chroma number of bins: " << result->chroma_n_bins << std::endl;
    std::cout << "chroma number of frames: " << result->chroma_n_frames << std::endl;

    return result;
}

// Cleanup 
void delete_analysis_result(EssentiaAnalysisResult* result) {
    if (result) {
        if (result->key) delete[] result->key;
        if (result->chromagram) delete[] result->chromagram;
        delete result;
    }
}

