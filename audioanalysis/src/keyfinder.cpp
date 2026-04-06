#include "keyfinder.h"
#include <algorithm>
#include <cmath>
#include <string>
#include <vector>



KeyFinder::KeyFinder(
    const std::vector<std::vector<float>>& chromaMatrix, 
    std::vector<std::string>& musicalKeys,
    const std::vector<float>& majorProfile,
    const std::vector<float>& minorProfile
): 
    chromaMatrix(chromaMatrix),     
    musicalKeys(musicalKeys),
    majorProfile(majorProfile),
    minorProfile(minorProfile)
{}

// Compute an average chroma vector across all time frames. Then compute its correlation with all templates (12 major, 12 minor).
// The output is a sorted list of candidate keys (largest correlation first).
void KeyFinder::computeKey() {
    if (chromaMatrix.empty()) {
        musicalKeys.clear();
        return;
    }
    // Compute average chroma vector
    std::vector<float> avgChroma = computeAverageChroma();

    // Compute mean and stddev of average chroma and templates
    float chromaMean = mean(avgChroma);
    float chromaStd = stddev(avgChroma, chromaMean);

    float majorMean = mean(majorProfile);
    float majorStd = stddev(majorProfile, majorMean);

    float minorMean = mean(minorProfile);
    float minorStd = stddev(minorProfile, minorMean);

    struct Candidate {
        std::string keyName;
        std::string mode;
        float correlation;
    };
    std::vector<Candidate> candidates;

    // Shift chroma vector for each tonic and compute correlations with major and minor profiles
    std::vector<float> chromaShifted(12);
    for (int tonic = 0; tonic < 12; ++tonic) {
        for (int i = 0; i < 12; ++i) {
            chromaShifted[i] = avgChroma[(i + tonic) % 12];
        }

        float corrMajor = computeCorrelation(chromaShifted, chromaMean, chromaStd, majorProfile, majorMean, majorStd);
        float corrMinor = computeCorrelation(chromaShifted, chromaMean, chromaStd, minorProfile, minorMean, minorStd);

        candidates.push_back({keyNames[tonic], "major", corrMajor});
        candidates.push_back({keyNames[tonic], "minor", corrMinor});
    }

    // Sort candidates by correlation
    std::sort(candidates.begin(), candidates.end(), [](const Candidate& a, const Candidate& b) {
        return a.correlation > b.correlation;
    });

    // Write output keys
    musicalKeys.clear();
    for (const auto& cand : candidates) {
        musicalKeys.push_back(cand.keyName + " " + cand.mode);
    }
}

// Compute average chroma vector for pitch classes across all time frames
std::vector<float> KeyFinder::computeAverageChroma() const {
    std::vector<float> avgChroma(12, 0.0f);
    int numFrames = static_cast<int>(chromaMatrix.size());
    if (numFrames == 0) return avgChroma;
    int numBins = static_cast<int>(chromaMatrix[0].size());
    if (numBins < 12) return avgChroma; // Not enough bins to compute chroma

    // We want to weigh each pitch class the same number of times
    int numBinsToConsider = numBins - numBins % 12; // Enforce multiple of 12

    for (const auto& frame : chromaMatrix) {
        for (int bin = 0; bin < numBinsToConsider; ++bin) {
            avgChroma[bin % 12] += frame[bin];
        }
    }
    for (int j = 0; j < 12; ++j) {
        avgChroma[j] /= numFrames;
    }
    return avgChroma;
}

// Compute Pearson correlation between two vectors
float KeyFinder::computeCorrelation(const std::vector<float>& v1, float mean1, float stddev1,
                                    const std::vector<float>& v2, float mean2, float stddev2) const {
    float sum = 0.0f;
    for (int i = 0; i < v1.size(); ++i) {
        sum += (v1[i] - mean1) * (v2[i] - mean2);
    }
    return sum / (v1.size() * stddev1 * stddev2);
}

// Compute mean of a vector
float KeyFinder::mean(const std::vector<float>& v) const {
    float sum = 0.0f;
    for (float x : v) sum += x;
    return sum / v.size();
}

// Compute standard deviation of a vector
float KeyFinder::stddev(const std::vector<float>& v, float mean) const {
    float sum = 0.0f;
    for (float x : v) sum += (x - mean) * (x - mean);
    return std::sqrt(sum / v.size());
}