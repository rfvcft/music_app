#include <vector>
#include <cmath>
#include <complex>
#include <algorithm>
#include <string>
#include <iostream>
#include <memory>

#include "audioanalyzer.h"
#include "framecutter.h"
#include "fouriertransformer.h"
#include "peakfinder.h"
#include "chromaconverter.h"
#include "keyfinder.h"
#include "chromaenhancer.h"

AudioAnalyzer::AudioAnalyzer(const std::vector<float>& audioBuffer, AudioAnalysisResult& analysisResult) 
    : audioVector(&audioBuffer), audioArray(nullptr), audioSize(audioBuffer.size()), result(analysisResult) {}

AudioAnalyzer::AudioAnalyzer(const float* audio_buffer, int audio_buffer_length, AudioAnalysisResult& analysisResult)
    : audioVector(nullptr), audioArray(audio_buffer), audioSize(audio_buffer_length), result(analysisResult) {}

void AudioAnalyzer::analyze() {
    // Set up algorithms
    std::vector<float> frame;
    std::unique_ptr<FrameCutter> frameCutter; // Needed for case distinction between vector and array input
    if (audioVector) {
        frameCutter = std::make_unique<FrameCutter>(*audioVector, frame);
    } else if (audioArray) {
        frameCutter = std::make_unique<FrameCutter>(audioArray, audioSize, frame);
    } else {
        throw std::runtime_error("No valid audio buffer provided.");
    }

    std::vector<std::complex<float>> spectrum;
    std::vector<float> magnitudes;
    std::vector<float> frequencies; 
    FourierTransformer fourierTransformer(frame, spectrum, magnitudes, frequencies);

    std::vector<float> peakMagnitudes;
    std::vector<float> peakFrequencies;
    PeakFinder peakFinder(magnitudes, frequencies, peakMagnitudes, peakFrequencies);

    std::vector<float> chroma;
    ChromaConverter chromaConverter(peakMagnitudes, peakFrequencies, chroma); 

    std::vector<std::vector<float>> chromaMatrix; // time frames x chroma bins
    std::vector<std::vector<float>> enhancedChromaMatrix;
    ChromaEnhancer chromaEnhancer(chromaMatrix, enhancedChromaMatrix);

    std::vector<std::string> musicalKeys;
    KeyFinder keyFinder(enhancedChromaMatrix, musicalKeys);

    // Process audio buffer frame by frame
    while (true) {
        frameCutter->computeNextFrame();
        if (frame.empty()) break; // End of audio buffer signaled by empty frame
        // Process the frame 
        fourierTransformer.computeSpectrumAndMagnitudes();
        peakFinder.computePeaks();
        chromaConverter.computeChroma();
        chromaMatrix.push_back(chroma);
    }

    chromaEnhancer.computeEnhancement();
    keyFinder.computeKey();

    result.chromaMatrix = enhancedChromaMatrix; // time frames x chroma bins
    result.musicalKeys = musicalKeys;
    result.duration = (float) audioSize / sampleRate;
}
