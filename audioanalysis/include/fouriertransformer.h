#pragma once
#include <vector>
#include <complex>

#if defined(__APPLE__)
#include <Accelerate/Accelerate.h>
#elif defined(__ANDROID__)
#include "../../third_party/pocketfft/pocketfft_hdronly.h"
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

#if defined(__APPLE__)
    void accelerateFFT();
    FFTSetup fftSetup = nullptr;
    std::vector<float> real;
    std::vector<float> imag;
#elif defined(__ANDROID__)
    void pocketFFT();
    pocketfft::shape_t input_shape;
    const pocketfft::stride_t input_stride{sizeof(float)};
    const pocketfft::stride_t output_stride{sizeof(std::complex<float>)};
#endif

    void primitiveFFT();
    float binToFrequency(float bin) const;
};