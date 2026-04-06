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
        std::vector<float>& chroma, // Output: chroma vector (pitch classes)
        float minFrequency, // Parameter: minimum frequency to consider, in Hz (Default: 40 Hz)
        float maxFrequency, // Parameter: maximum frequency to consider, in Hz (Default: 3500 Hz)
        bool octaveReduced, // Parameter: If true, output chroma vector will be octave reduced and numBins will be set to 12. If false bin 0 corresponds to C2 = MIDI 36 (Default: true) 
        int numBins, // Parameter: Number of chroma bins (set to 12 if octaveReduced = true) (Default: 12)
        bool useSmoothTransition, // Parameter: Use smooth transition at semitone boundaries (Default: true)
        std::string overtoneFilter // Parameter: What type of overtone filter we want to use. ("none", "basic", "nnls") (Default: "basic")
    );

    void computeChroma();

private:
    std::vector<Peak>& peaks;
    std::vector<float>& chroma; 
    float minFrequency;
    float maxFrequency;
    bool octaveReduced;
    int numBins;
    bool useSmoothTransition;
    std::string overtoneFilter;

    // Octave reduced case
    float referenceFrequency = 220.0f; // reference frequency for A3, in Hz
    int referencePitchClass = 9; // reference pitch class for A (0=C, 1=C#, ..., 9=A, ..., 11=B)

    // Non-octave reduced case
    int midiNoteC2 = 36; // MIDI note number corresponding to C2, which is the start of our chroma bins if octaveReduced = false
    int midiNoteC6 = 84; // MIDI note number corresponding to C6
    int minOutputMIDI;; // MIDI note corresponding to chroma bin 0
    int maxOutputMIDI; // MIDI numBins above minOutputMIDI

    void computeChromaWithoutOvertoneFilter();
    void computeChromaWithBasicOvertoneFilter();

    // NNLS related
    int numCandidates = 10; // Number of fundamental frequencies candidates we consider
    float decayFactor = 0.8f; // For overtone weights
    std::vector<int> overtonePattern = {0, 12, 19, 24, 28, 31}; // Pattern of overtones in semitones (5 harmonics)
    std::vector<float> overtoneWeights = {1.0f, decayFactor, decayFactor * decayFactor, decayFactor * decayFactor * decayFactor, decayFactor * decayFactor * decayFactor * decayFactor, decayFactor * decayFactor * decayFactor * decayFactor * decayFactor}; 
    int minComputationMIDI; // MIDI range in which we do computations (derived from minFrequency)
    int maxComputationMIDI; // MIDI range in which we do computations (derived from maxFrequency)
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