#pragma once
#include "peakfinder.h" // for Peak struct 
#include <string>
#include <vector>
#include <cmath>
#include "../third_party/eigen/Eigen/Dense"



// Converts magnitude peaks to a 12 dimensional chroma vector (pitch classes). Overtones are filtered. 
class ChromaConverter {
public:
    ChromaConverter(
        std::vector<Peak>& peaks, // Input: peaks (magnitude and frequency) 
        std::vector<float>& chroma, // Output: chroma vector (chroma bin 0 corresponds to C2 = MIDI 36)
        float minFrequency, // Parameter: minimum frequency to consider, in Hz (Default: 40 Hz)
        float maxFrequency, // Parameter: maximum frequency to consider, in Hz (Default: 3500 Hz)
        int numBins, // Parameter: Number of chroma bins, bin 0 corresponds to C2 = MIDI 36 (Default: 48)
        bool useSmoothTransition, // Parameter: Use smooth transition at semitone boundaries (Default: true)
        std::string overtoneFilter // Parameter: What type of overtone filter we want to use. ("none", "basic", "nnls") (Default: "basic")
    );

    void computeChroma();

private:
    std::vector<Peak>& peaks;
    std::vector<float>& chroma; 
    float minFrequency;
    float maxFrequency;
    int numBins;
    bool useSmoothTransition;
    std::string overtoneFilter;

    // Non-octave reduced case
    int midiNoteC1 = 24; // MIDI note number corresponding to C1, which is the start of our chroma bins
    int midiNoteA1 = 33; // MIDI note number corresponding to A1, which is the start of where we search for fundamental frequencies
    int minOutputMIDI; // MIDI note corresponding to chroma bin 0
    int maxOutputMIDI; // MIDI numBins above minOutputMIDI

    void computeChromaWithoutOvertoneFilter();
    void computeChromaWithBasicOvertoneFilter();

    // NNLS related
    int numCandidates = 15; // Number of fundamental frequencies candidates we consider
    std::vector<int> overtonePattern = {0, 12, 19, 24, 28, 31}; // Pattern of overtones in semitones (5 harmonics)
    std::vector<float> overtoneWeights = {1.000f, 1.163f, 0.461f, 0.355f, 0.341f, 0.200f}; 
    int minComputationMIDI; // MIDI range in which we do computations (derived from minFrequency)
    int maxComputationMIDI; // MIDI range in which we do computations (derived from maxFrequency)
    int numBinsComputation; // maxComputationMIDI - minComputationMIDI
    int minFundamentalMIDI; // MIDI range for fundamental candidates
    int maxFundamentalMIDI; // MIDI range for fundamental candidates
    std::vector<std::pair<float, int>> largestElements; // pair of (magnitude, MIDI note)
    Eigen::MatrixXd A;
    Eigen::VectorXd b;
    Eigen::VectorXd x;

    void setupNNLS();
    void computeChromaWithNNLSOvertoneFilter(); 
    float smoothTransition(float x) const;
};