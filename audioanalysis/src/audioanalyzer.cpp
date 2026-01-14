#include "audioanalyzer.h"
#include "chromaconverter.h"
#include "chromaenhancer.h"
#include "fouriertransformer.h"
#include "framecutter.h"
#include "keyfinder.h"
#include "peakfinder.h"
#include "percussionremover.h"


AudioAnalyzer::AudioAnalyzer(const float* audio_buffer, int audio_buffer_length, AudioAnalysisResult& analysisResult)
    : audioBuffer(audio_buffer), audioBufferLength(audio_buffer_length), result(analysisResult) {}

void AudioAnalyzer::analyze() {
    // Set up algorithms
    std::vector<float> frame;
    FrameCutter frameCutter(audioBuffer, audioBufferLength, frame);
    
    std::vector<float> magnitudes; 
    FourierTransformer fourierTransformer(frame, magnitudes); 

    std::vector<float> noPercussionMagnitudes;
    PercussionRemover percussionRemover(magnitudes, noPercussionMagnitudes);

    std::vector<Peak> peaks;
    PeakFinder peakFinder(noPercussionMagnitudes, peaks);

    std::vector<float> chroma;
    ChromaConverter chromaConverter(peaks, chroma);

    std::vector<std::vector<float>> chromaMatrix; // time frames x chroma bins
    std::vector<std::vector<float>> enhancedChromaMatrix;
    ChromaEnhancer chromaEnhancer(chromaMatrix, enhancedChromaMatrix);

    std::vector<std::string> musicalKeys;
    KeyFinder keyFinder(enhancedChromaMatrix, musicalKeys);

    // Process audio buffer frame by frame
    while (true) {
        frameCutter.computeNextFrame();
        fourierTransformer.computeMagnitudes();
        percussionRemover.computePercussionRemoval();

        if (noPercussionMagnitudes.empty()) { // Two cases:
            // 1. At start, percussionRemover has not seen enough frames yet.
            // 2. At end, audio buffer has ended and percussionRemover has exhausted internal history.
            if (frame.empty()) break; // Case 2
            continue; // Case 1
        }

        peakFinder.computePeaks();
        chromaConverter.computeChroma();
        chromaMatrix.push_back(chroma);
    }

    chromaEnhancer.computeEnhancement();
    keyFinder.computeKey();

    result.chromaMatrix = enhancedChromaMatrix; // time frames x chroma bins
    result.musicalKeys = musicalKeys;
    result.duration = static_cast<float>(audioBufferLength) / static_cast<float>(sampleRate);
}
