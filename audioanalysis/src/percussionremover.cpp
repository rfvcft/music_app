#include "percussionremover.h"
#include <cmath>
#include <algorithm>
#include <vector>


// Erase one instance of x from sorted vector vec
void erase_one(std::vector<float>& vec, float x) {
    const float EPS = 1e-9f;
    auto it = std::find_if(vec.begin(), vec.end(), [&](float v){ return std::fabs(v - x) <= EPS; });
    if (it != vec.end()) {
        vec.erase(it);
    } else {
        // Shouldn't happen; as a safe fallback remove closest element
        if (!vec.empty()) {
            auto it_closest = std::min_element(vec.begin(), vec.end(), [&](float a, float b){
                return std::fabs(a - x) < std::fabs(b - x);
            });
            vec.erase(it_closest);
        }
    }
}

// Insert x into sorted vector vec, maintaining sorted order
void insert(std::vector<float>& vec, float x) {
    auto it = std::lower_bound(vec.begin(), vec.end(), x);
    vec.insert(it, x);
}

PercussionRemover::PercussionRemover(
    const std::vector<float>& magnitudeBuffer,
    std::vector<float>& noPercussionMagnitudeBuffer)
    : magnitudes(magnitudeBuffer), noPercussionMagnitudes(noPercussionMagnitudeBuffer) {
    
    // Initialize magMatrix with 0's
    magMatrix.resize(magMatrixRows, std::vector<float>(magMatrixCols, 0.0f)); // time frames x frequency bins

    // Initialize sortedBinSlices as the transpose of magMatrix. sortedBinSlices maintains the bin slices of magMatrix in sorted order
    sortedBinSlices.resize(magMatrixCols, std::vector<float>(magMatrixRows, 0.0f)); // frequency bins x time frames 

    // Initialize per-bin masks
    percussiveMask.resize(magMatrixCols, 0.0f);
    harmonicMask.resize(magMatrixCols, 0.0f);

    noPercussionMagnitudes.reserve(static_cast<size_t>(magnitudesSize));
}

// Compute percussive mask as the sliding median over magMatrix's middle frame slice 
void PercussionRemover::computePercussiveMask() {
    const size_t midLogical = static_cast<size_t>(magMatrixRows / 2);
    const std::vector<float>& frameSlice = magMatrix[(magHead + midLogical) % magMatrixRows];
    int n = static_cast<int>(frameSlice.size());

    const int k = medianLengthInBins;
    if (k <= 0 || n <= 0) {
        percussiveMask.clear();
        return;
    }

    percussiveMask.assign(static_cast<size_t>(n), 0.0f);

    std::vector<float> window;
    window.reserve(static_cast<size_t>(k));

    int half = k / 2; // floor(k/2)
    int left0 = 0 - half;
    int right0 = left0 + k - 1;

    // seed initial window (with zero-padding)
    for (int j = left0; j <= right0; ++j) {
        float val = (j < 0 || j >= n) ? 0.0f : frameSlice[j];
        insert(window, val);
    }

    // median index: lower median
    int midIndex = (k - 1) / 2;
    if (!window.empty()) percussiveMask[0] = window[static_cast<size_t>(midIndex)];

    int left = left0;
    int right = right0;
    const float EPS = 1e-9f;
    for (int i = 1; i < n; ++i) {
        int out_idx = left; // index leaving window
        int in_idx = right + 1; // index entering window

        float out_val = (out_idx < 0 || out_idx >= n) ? 0.0f : frameSlice[out_idx];
        float in_val  = (in_idx  < 0 || in_idx  >= n) ? 0.0f : frameSlice[in_idx];

        // erase one instance of outgoing value (helper handles FP tolerance)
        erase_one(window, out_val);

        // insert incoming (maintains sorted order)
        insert(window, in_val);


        // record median
        if (!window.empty()) percussiveMask[static_cast<size_t>(i)] = window[static_cast<size_t>(midIndex)];

        left += 1;
        right += 1;
    }
}

// Insert frameSlice into sortedBinSlices, maintaining each bin slice in sorted order
void PercussionRemover::insertIntoBinSlices(const std::vector<float>& frameSlice) {
    for (size_t bin = 0; bin < sortedBinSlices.size(); ++bin) {
        // Insert frameSlice[bin] into sortedBinSlices[bin]
        insert(sortedBinSlices[bin], frameSlice[bin]);
    }
}

// Erase frameSlice from sortedBinSlices
void PercussionRemover::eraseFromBinSlices(const std::vector<float>& frameSlice) {
    for (size_t bin = 0; bin < sortedBinSlices.size(); ++bin) {
        // Erase one instance of frameSlice[bin] from sortedBinSlices[bin]
        erase_one(sortedBinSlices[bin], frameSlice[bin]);
    }
}

// Compute harmonic mask as the median over each bin slice. 
// Since sortedBinSlices is maintained in sorted order, the median is at the middle index.
void PercussionRemover::computeHarmonicMask() {
    size_t midIdx = (medianLengthInFrames - 1) / 2; // picks upper-middle when rows is even
    for (size_t bin = 0; bin < sortedBinSlices.size(); ++bin) {
        harmonicMask[bin] = sortedBinSlices[bin][midIdx];
    }
}

// Compute percussive and harmonic masks and combine them to produce noPercussionMagnitudes
void PercussionRemover::computePercussionRemoval() {
    if (deactive) {
        noPercussionMagnitudes = magnitudes;
        return;
    }

    // Add input to internal state
    updateInternalStates();
    if (magCount < sufficientMagCount) {
        noPercussionMagnitudes.clear();
        return;
    }

    // Compute masks
    computePercussiveMask();
    computeHarmonicMask();

    // Combine masks and apply to magMatrix's middle frame slice
    noPercussionMagnitudes.resize(static_cast<size_t>(magnitudesSize));

    const size_t midLogical = static_cast<size_t>(magMatrixRows / 2);
    const std::vector<float>& middleFrameSlice = magMatrix[(magHead + midLogical) % magMatrixRows];
    const float eps = 1e-5f;
    for (size_t i = 0; i < magMatrixCols; ++i) {

        float perc = percussiveMask[i];
        float harm = harmonicMask[i];
        float max = std::max(perc, harm);

        // middleFrameSlice stores only the restricted bins [minBin..maxBin]
        if (max < eps) {
            noPercussionMagnitudes[i + minBin] = 0.0f;
            continue;
        }
        
        float stablePerc = (perc / max);
        float stableHarm = (harm / max);
        float smoothMask = (stableHarm * stableHarm) / (stableHarm * stableHarm + stablePerc * stablePerc);

        noPercussionMagnitudes[i + minBin] = smoothMask * middleFrameSlice[i];
    }
}

// Update magMatrix and sortedBinSlices with the current magnitudes buffer
void PercussionRemover::updateInternalStates() {
    // Case empty input magnitudes: Add trivial frame slice
    if (magnitudes.empty()) {
        // Erase the oldest frame 
        eraseFromBinSlices(magMatrix[magHead]);

        // Add trivial frame slice to magMatrix
        std::vector<float> trivialFrameSlice(magMatrixCols, 0.0f);
        addToMagMatrix(trivialFrameSlice);
        insertIntoBinSlices(trivialFrameSlice);

        magCount--; // decrement the count of non-trivial frame slices
        return;
    }
    
    // Case non-empty input magnitudes:
    // Remove oldest frame 
    eraseFromBinSlices(magMatrix[magHead]);
    
    // Add new frame slice to magMatrix 
    addToMagMatrix(magnitudes);
    insertIntoBinSlices(magnitudes);

    if (magCount < magMatrix.size()) magCount++; // increment count of non-trivial frame slices
}

// Add magnitudes buffer to magMatrix 
// We only write the frequency bins in the range [minBin..maxBin]
void PercussionRemover::addToMagMatrix(const std::vector<float>& magBuffer) {

    // Write the new frame in-place into the slot pointed to by magHead
    for (size_t bin = 0; bin < magMatrixCols; ++bin) {
        // Shift frequency bins to minBin..maxBin
        magMatrix[magHead][bin] = magBuffer[bin + minBin];
    }

    // Advance head to point to the new oldest frame
    magHead = (magHead + 1) % magMatrixRows;
}