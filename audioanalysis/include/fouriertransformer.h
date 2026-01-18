#pragma once
#include <vector>
#include <complex>

#if defined(__APPLE__)
#include <Accelerate/Accelerate.h>
#elif defined(__ANDROID__) || defined(__linux__)
#include "../third_party/pocketfft/pocketfft_hdronly.h"
#endif

// Computes magnitude spectrum of a frame. The magnitude spectrum is given by 
// magnitudes[k] = | sum_{n=0}^{N-1} frame[n] * exp(-2πi * k * n / N) | for k = 0, ..., N/2 |,
// where N is the size of the frame. We use the FFT in the computation.
class FourierTransformer {
public:
    FourierTransformer(
        const std::vector<float>& frameBuffer, // Input: frame buffer, size N
        std::vector<float>& magnitudeBuffer // Output: magnitude spectrum, size N/2 + 1
    );

    ~FourierTransformer(); 

    void computeMagnitudes();

private:
    const std::vector<float>& frame; 
    std::vector<std::complex<float>> spectrum; 
    std::vector<float>& magnitudes;  

#if defined(__APPLE__)
    void accelerateFFT();
    FFTSetup fftSetup = nullptr;
    std::vector<float> real;
    std::vector<float> imag;
#elif defined(__ANDROID__) || defined(__linux__)
    void pocketFFT();
    pocketfft::shape_t input_shape;
    const pocketfft::stride_t input_stride{sizeof(float)};
    const pocketfft::stride_t output_stride{sizeof(std::complex<float>)};
#endif

    void primitiveFFT();
};