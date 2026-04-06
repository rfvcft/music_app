#pragma once
#include <vector>
#include <complex>


#if defined(__APPLE__)
#include <Accelerate/Accelerate.h>
#endif
#include "../third_party/pocketfft/pocketfft_hdronly.h"

// Computes magnitude spectrum of a frame. The magnitude spectrum is given by 
// magnitudes[k] = | sum_{n=0}^{N-1} frame[n] * exp(-2πi * k * n / N) | for k = 0, ..., N/2 |,
// where N is the size of the frame. We use the FFT in the computation.
class FourierTransformer {
public:
    FourierTransformer(
        const std::vector<float>& frame, // Input: frame buffer, size N
        std::vector<float>& magnitudes // Output: magnitude spectrum, size N/2 + 1
    );

    ~FourierTransformer(); 

    void computeMagnitudes();

private:
    const std::vector<float>& frame; 
    std::vector<std::complex<float>> spectrum; 
    std::vector<float>& magnitudes;  


    // Always declare pocketFFT and its members for cross-platform use
    void pocketFFT();
    pocketfft::shape_t input_shape;
    const pocketfft::stride_t input_stride{sizeof(float)};
    const pocketfft::stride_t output_stride{sizeof(std::complex<float>)};

#if defined(__APPLE__)
    void accelerateFFT();
    FFTSetup fftSetup = nullptr;
    std::vector<float> real;
    std::vector<float> imag;
#endif

    void primitiveFFT();
};