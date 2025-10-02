#pragma once
#include <vector>
#include <complex>

#ifdef __APPLE__
#include <Accelerate/Accelerate.h>
#endif

// Computes the FFT and magnitude spectrum of a frame.
class FourierTransformer {
public:
    FourierTransformer(
        const std::vector<float>& frameBuffer, // Input: frame buffer, size N
        std::vector<std::complex<float>>& spectrumBuffer, // Output: complex spectrum, size N/2 + 1
        std::vector<float>& magnitudeBuffer, // Output: magnitude spectrum, size N/2 + 1
        std::vector<float>& frequencyBuffer // Output: frequencies corresponding to magnitudes, size N/2 + 1
    );

    // Parameters
    int sampleRate = 44100; // samplerate of audio buffer, in Hz

    ~FourierTransformer(); 

    void computeSpectrumAndMagnitudes();

private:
    const std::vector<float>& frame; 
    std::vector<std::complex<float>>& spectrum; 
    std::vector<float>& magnitudes;  
    std::vector<float>& frequencies; 

#ifdef __APPLE__
    void accelerateFFT();
    FFTSetup fftSetup = nullptr;
    std::vector<float> real;
    std::vector<float> imag;
#endif

    void primitiveFFT();
    float binToFrequency(float bin) const;
};