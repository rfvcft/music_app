#include "capi.h"

#include <iostream>
#include <vector>
#include <fstream>
#include <sstream>
#include <map>

// This is a simple example of using the C API to analyze an audio buffer
int main(int argc, char** argv) {
    if (argc < 2) {
        std::cerr << "Usage: " << argv[0] << " audio.wav | audio.mp3 | audio.flac \n";
        return 1;
    }
    char *inputPath = argv[1];

    // Analyze
    CAudioAnalysisResult* resultPtr = analyze_audio_file(inputPath); 

    // Log results
    std::cout << "Detected Key: " << (resultPtr->key[0] ? resultPtr->key : "Unknown") << std::endl;
    std::cout << "Duration: " << resultPtr->duration << " seconds" << std::endl;
    std::cout << "Chromagram size: " << resultPtr->chroma_n_frames << " frames, " << resultPtr->chroma_n_bins << " bins" << std::endl;
    
    // Clean up 
    delete_analysis_result(resultPtr);

    return 0;
}
