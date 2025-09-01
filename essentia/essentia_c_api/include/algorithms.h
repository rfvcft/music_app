
#pragma once

#include <vector>
#include <string>
#include <essentia/essentia.h>


// Loads a float audio buffer from a binary file (raw float32 LE)
std::vector<essentia::Real> loadAudioBufferFromFile(const std::string& filePath);

// Converts a float* buffer with length to a std::vector<essentia::Real>
std::vector<essentia::Real> audioBufferToVector(const float* buffer, int buffer_length);

// Computes the musical key from an audio buffer
std::string computeKey(const std::vector<essentia::Real>& audio);

// Computes the duration (in seconds) from an audio buffer (assumes 44100Hz)
float computeDuration(const std::vector<essentia::Real>& audio);


// Computes the chromagram (HPCP matrix) from an audio buffer
// Returns a vector of vectors, shape: [n_bins][n_frames] (after transpose in implementation).
std::vector<std::vector<essentia::Real>> computeHPCP(const std::vector<essentia::Real>& audio);

// Enhances the chromagram matrix in-place
void enhance(std::vector<std::vector<essentia::Real>>& matrix);
