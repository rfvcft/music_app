#pragma once
#include <cmath>


// (TIME) Convert seconds to samples 
inline int secondsToSamples(float seconds, int sampleRate) {
    return static_cast<int>(std::round(seconds * sampleRate));
}

// (TIME) Convert samples to seconds
inline float samplesToSeconds(int samples, int sampleRate) {
    return samples / static_cast<float>(sampleRate);
}

// (TIME) Convert seconds to frames  
inline int secondsToFrames(float seconds, int sampleRate, int hopSize) {
    return static_cast<int>(std::round(seconds * sampleRate / static_cast<float>(hopSize))); // = samples / hopSize
}

// (TIME) Convert frames to seconds
inline float framesToSeconds(int frames, int sampleRate, int hopSize) {
    return frames * static_cast<float>(hopSize) / static_cast<float>(sampleRate);
}

// (FREQUENCY) Convert frequency in Hz to FFT bin index
// Note: This assumes a standard FFT binning where bin 0 corresponds to 0 Hz and bin N/2 corresponds to Nyquist frequency (sampleRate/2).
inline int frequencyToBin(float frequency, int sampleRate, int frameSize) {
    return static_cast<int>(std::round(frequency * frameSize / static_cast<float>(sampleRate)));
}

// (FREQUENCY) Convert FFT bin index to frequency in Hz
// Note: This assumes a standard FFT binning where bin 0 corresponds to 0 Hz and bin N/2 corresponds to Nyquist frequency (sampleRate/2).
inline float binToFrequency(int bin, int sampleRate, int frameSize) {
    return bin * static_cast<float>(sampleRate) / static_cast<float>(frameSize);
}

// (FREQUENCY) Convert frequency in Hz to MIDI note number (where MIDI note 69 corresponds to A4 = 440 Hz)
inline float frequencyToMIDI(float frequency) {
    return 69 + 12 * std::log2f(frequency / 440.0f);
}

// (FREQUENCY) Convert MIDI note number to frequency in Hz (where MIDI note 69 corresponds to A4 = 440 Hz)
inline float MIDIToFrequency(int midiNote) {
    return 440.0f * std::pow(2.0f, (midiNote - 69) / 12.0f);
}
