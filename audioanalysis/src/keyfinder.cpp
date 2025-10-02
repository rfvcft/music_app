#include "keyfinder.h"
#include <algorithm>
#include <cmath>
#include <string>
#include <vector>

// bgate
//std::vector<float> majorProfile = { 1.00, 0.00, 0.42, 0.00, 0.53, 0.37, 0.00, 0.77, 0.00, 0.38, 0.21, 0.30 };
//std::vector<float> minorProfile = { 1.00, 0.00, 0.36, 0.39, 0.00, 0.38, 0.00, 0.74, 0.27, 0.00, 0.42, 0.23 };

// braw 
//std::vector<float> majorProfile = { 1.0000, 0.1573, 0.4200, 0.1570, 0.5296, 0.3669, 0.1632, 0.7711, 0.1676, 0.3827, 0.2113, 0.2965 };
//std::vector<float> minorProfile = { 1.0000, 0.2330, 0.3615, 0.3905, 0.2925, 0.3777, 0.1961, 0.7425, 0.2701, 0.2161, 0.4228, 0.2272 };


// Recommended by ChatGPT, fundamental only 
std::vector<float> majorProfile = { 1.00, 0.00, 0.55, 0.00, 0.85, 0.55, 0.00, 0.90, 0.00, 0.70, 0.00, 0.50 };
std::vector<float> minorProfile = { 1.00, 0.00, 0.55, 0.85, 0.00, 0.55, 0.00, 0.90, 0.70, 0.00, 0.50, 0.00 };

std::vector<std::string> keyNames = { "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B" };

KeyFinder::KeyFinder(const std::vector<std::vector<float>>& chromaMat, std::vector<std::string>& keys)
    : chromaMatrix(chromaMat), musicalKeys(keys) {}

void KeyFinder::computeKey() {
    std::vector<float> avgChroma = computeAverageChroma();

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

    for (int tonic = 0; tonic < 12; ++tonic) {
        std::vector<float> chromaShifted(12);
        for (int i = 0; i < 12; ++i) {
            chromaShifted[i] = avgChroma[(i + tonic) % 12];
        }

        float corrMajor = computeCorrelation(chromaShifted, chromaMean, chromaStd, majorProfile, majorMean, majorStd);
        float corrMinor = computeCorrelation(chromaShifted, chromaMean, chromaStd, minorProfile, minorMean, minorStd);

        candidates.push_back({keyNames[tonic], "major", corrMajor});
        candidates.push_back({keyNames[tonic], "minor", corrMinor});
    }

    std::sort(candidates.begin(), candidates.end(), [](const Candidate& a, const Candidate& b) {
        return a.correlation > b.correlation;
    });

    musicalKeys.clear();
    for (const auto& cand : candidates) {
        musicalKeys.push_back(cand.keyName + " " + cand.mode);
    }
}

std::vector<float> KeyFinder::computeAverageChroma() const {
    std::vector<float> avgChroma(12, 0.0f);
    for (const auto& frame : chromaMatrix) {
        for (int j = 0; j < 12; ++j) {
            avgChroma[j] += frame[j];
        }
    }
    for (int j = 0; j < 12; ++j) {
        avgChroma[j] /= chromaMatrix.size();
    }
    return avgChroma;
}

float KeyFinder::computeCorrelation(const std::vector<float>& v1, float mean1, float stddev1,
                                    const std::vector<float>& v2, float mean2, float stddev2) const {
    float sum = 0.0f;
    for (int i = 0; i < v1.size(); ++i) {
        sum += (v1[i] - mean1) * (v2[i] - mean2);
    }
    return sum / (v1.size() * stddev1 * stddev2);
}

float KeyFinder::mean(const std::vector<float>& v) const {
    float sum = 0.0f;
    for (float x : v) sum += x;
    return sum / v.size();
}

float KeyFinder::stddev(const std::vector<float>& v, float mean) const {
    float sum = 0.0f;
    for (float x : v) sum += (x - mean) * (x - mean);
    return std::sqrt(sum / v.size());
}