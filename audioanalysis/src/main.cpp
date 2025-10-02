#include "capi.h"

#include <iostream>
#include <vector>
#include <fstream>
#include <sstream>
#include <map>


// Load .raw file to audio buffer. 
std::vector<float> loadRawFile(const std::string& filePath) {
    std::ifstream inFile(filePath, std::ios::binary | std::ios::ate);
    if (!inFile) {
        throw std::runtime_error("Failed to open file for reading: " + filePath);
    }

    std::streamsize fileSize = inFile.tellg();
    inFile.seekg(0, std::ios::beg);

    if (fileSize % sizeof(float) != 0) {
        throw std::runtime_error("Invalid file size (not aligned to float): " + filePath);
    }

    std::vector<float> buffer(fileSize / sizeof(float));
    if (!inFile.read(reinterpret_cast<char*>(buffer.data()), fileSize)) {
        throw std::runtime_error("Failed to read data from file: " + filePath);
    }

    return buffer;
}

int main(int argc, char** argv) {
    if (argc < 2) {
        std::cerr << "Usage: " << argv[0] << " audio.raw \n";
        return 1;
    }

    // Load audio buffer to memory
    std::vector<float> audio = loadRawFile(argv[1]);

    // Convert to float* for C API
    float* audio_buffer = audio.data();
    int audio_buffer_length = audio.size();

    // Analyze
    CAudioAnalysisResult* resultPtr = analyze_audio_buffer(audio_buffer, audio_buffer_length); 

    // Log results
    std::cout << "Detected Key: " << (resultPtr->key[0] ? resultPtr->key : "Unknown") << std::endl;
    std::cout << "Duration: " << resultPtr->duration << " seconds" << std::endl;
    std::cout << "Chroma Matrix: " << resultPtr->chroma_n_frames << " frames, " << resultPtr->chroma_n_bins << " bins" << std::endl;
    
    // Clean up 
    delete_analysis_result(resultPtr);

    return 0;
}
