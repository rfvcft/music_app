#pragma once
#include <vector>
#include <string>
#include <algorithm>
#include <cmath>

// Finds the musical key from a chroma matrix. Outputs a sorted list of candidate keys (best match first).
class KeyFinder {
public:
    KeyFinder(
        const std::vector<std::vector<float>>& chromaMatrix, // Input: chroma matrix ( time frames x pitch classes)
        std::vector<std::string>& musicalKeys, // Output: detected musical keys, sorted by correlation score
        const std::vector<float>& majorProfile, // Parameter: major key template profile (size 12)
        const std::vector<float>& minorProfile, // Parameter: minor key template profile (size 12)
        int minBin, // Parameter: minimum bin range to consider (-1 to bypass)
        int maxBin // Parameter: maximum bin range to consider (-1 to bypass)
    );

    // Music related parameters
    std::vector<std::string> keyNames = { "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B" };

    void computeKey();

private:
    const std::vector<std::vector<float>>& chromaMatrix; 
    std::vector<std::string>& musicalKeys; 
    const std::vector<float>& majorProfile; 
    const std::vector<float>& minorProfile; 
    const int minBin;
    const int maxBin;

    std::vector<float> computeAverageChroma() const;
    float computeCorrelation(const std::vector<float>& v1, float mean1, float stddev1,
                            const std::vector<float>& v2, float mean2, float stddev2) const;
    float mean(const std::vector<float>& v) const;
    float stddev(const std::vector<float>& v, float mean) const;
};