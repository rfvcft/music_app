#include "audioanalyzer.h"
#include "chromaconverter.h"
#include "chromaenhancer.h"
#include "conversion.h" // Time and frequency conversion 
#include "fouriertransformer.h"
#include "framecutter.h"
#include "keyfinder.h"
#include "parameters.h" // Parameters used in algorithms 
#include "peakfinder.h"
#include "percussionremover.h"


AudioAnalyzer::AudioAnalyzer(
    const float* audio_buffer, 
    int audio_buffer_length, 
    int sampleRate,
    AudioAnalysisResult& result
): 
    audio_buffer(audio_buffer), 
    audio_buffer_length(audio_buffer_length), 
    sampleRate(sampleRate),
    result(result) 
{}

void AudioAnalyzer::analyze() {
    // Set up algorithms
    std::vector<float> frame;
    FrameCutter frameCutter(
        audio_buffer, // Input
        audio_buffer_length, // Input
        frame, // Output
        frameSize, // Parameter
        hopSize, // Parameter
        frameCutterCurrentPositionAt // Parameter
    );
    
    std::vector<float> magnitudes; 
    FourierTransformer fourierTransformer(
        frame, // Input
        magnitudes // Output
    ); 

    std::vector<float> noPercussionMagnitudes;
    PercussionRemover percussionRemover(
        magnitudes, // Input
        noPercussionMagnitudes, // Output
        sampleRate, // Parameter
        frameSize, // Parameter
        hopSize, // Parameter
        percussionRemoverMedianLengthInSeconds, // Parameter
        percussionRemoverMedianLengthInHertz, // Parameter
        percussionRemoverMinFrequency, // Parameter
        percussionRemoverMaxFrequency, // Parameter
        percussionRemoverDeactive // Parameter
    );

    std::vector<Peak> peaks;
    PeakFinder peakFinder(
        noPercussionMagnitudes, // Input
        peaks, // Output
        sampleRate, // Parameter
        frameSize, // Parameter
        peakFinderMinFrequency, // Parameter
        peakFinderMaxFrequency, // Parameter
        peakFinderMaxPeaks // Parameter
    );

    std::vector<float> chroma;
    ChromaConverter chromaConverter(
        peaks, // Input
        chroma, // Output
        chromaConverterMinFrequency, // Parameter
        chromaConverterMaxFrequency, // Parameter
        chromaConverterNumBins, // Parameter
        chromaConverterUseSmoothTransition, // Parameter
        chromaConverterOvertoneFilter // Parameter
    );

    std::vector<std::vector<float>> chromaMatrix; // time frames x chroma bins
    std::vector<std::vector<float>> enhancedChromaMatrix;
    ChromaEnhancer chromaEnhancer(
        chromaMatrix, // Input
        enhancedChromaMatrix, // Output
        sampleRate, // Parameter
        hopSize, // Parameter
        chromaEnhancerLocalMaxWindowSizeInSeconds, // Parameter
        chromaEnhancerLowAmplitudeThreshold, // Parameter
        chromaEnhancerMedianLengthInSeconds, // Parameter
        chromaEnhancerMinDurationInSeconds, // Parameter
        chromaEnhancerDeactive // Parameter
    );

    std::vector<std::string> musicalKeys;
    KeyFinder keyFinder(
        enhancedChromaMatrix, // Input
        musicalKeys, // Output
        keyFinderMajorProfile, // Parameter
        keyFinderMinorProfile, // Parameter
        keyFinderMinBin, // Parameter
        keyFinderMaxBin // Parameter
    );

    // Process audio buffer frame by frame
    while (true) {
        frameCutter.computeNextFrame();
        fourierTransformer.computeMagnitudes();
        percussionRemover.computePercussionRemoval();

        if (percussionRemover.hasNotSeenEnoughFrames()) { continue; } // Not enough history yet to produce output
        if (percussionRemover.isFinished()) { break; } // Internal history is exhausted

        peakFinder.computePeaks();
        chromaConverter.computeChroma();
        chromaMatrix.push_back(chroma); // Collect chroma vectors into chroma matrix (time frames x chroma bins)
    }

    chromaEnhancer.computeEnhancement();
    keyFinder.computeKey();

    result.chromaMatrix = enhancedChromaMatrix; // time frames x chroma bins
    result.musicalKeys = musicalKeys;
    result.duration = samplesToSeconds(audio_buffer_length, sampleRate);
}
