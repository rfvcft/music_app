#pragma once
#include <vector>
#include <string>
#include <algorithm>
#include <cmath>

class KeyFinder {
public:
    KeyFinder(
        const std::vector<std::vector<float>>& chromaMat, // Input: chroma matrix ( time frames x pitch classes)
        std::vector<std::string>& keys // Output: detected musical keys, sorted by correlation score
    );

    void computeKey();

private:
    const std::vector<std::vector<float>>& chromaMatrix; // Input chroma matrix (time frames x pitch classes)
    std::vector<std::string>& musicalKeys; // Output detected musical keys, sorted by correlation score

    std::vector<float> computeAverageChroma() const;
    float computeCorrelation(const std::vector<float>& v1, float mean1, float stddev1,
                            const std::vector<float>& v2, float mean2, float stddev2) const;
    float mean(const std::vector<float>& v) const;
    float stddev(const std::vector<float>& v, float mean) const;
};