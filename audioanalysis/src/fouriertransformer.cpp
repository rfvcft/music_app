#include "fouriertransformer.h"
#include <cmath>
#include <algorithm>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

FourierTransformer::FourierTransformer(const std::vector<float>& frameBuffer,
                                       std::vector<float>& magnitudeBuffer)
    : frame(frameBuffer), magnitudes(magnitudeBuffer)
#ifdef __APPLE__
    , fftSetup(nullptr), real(frameBuffer.size(), 0.0f), imag(frameBuffer.size(), 0.0f)
#endif
{   
    // Preallocate buffers
    int N = frame.size();
    spectrum.resize(N / 2 + 1, std::complex<float>(0.0f, 0.0f));
    magnitudes.resize(N / 2 + 1, 0.0f);
}

// Destructor. Needed to clean up FFT setup
FourierTransformer::~FourierTransformer() {
#ifdef __APPLE__
    if (fftSetup) {
        vDSP_destroy_fftsetup(fftSetup);
        fftSetup = nullptr;
    }
#endif
}

// Computes magnitude spectrum of frame
void FourierTransformer::computeMagnitudes() {
    if (frame.empty()) {
        magnitudes.clear();
        return;
    }

    // Compute spectrum using FFT (complex valued)
#if defined(__APPLE__)
    accelerateFFT();
#elif defined(__ANDROID__) || defined(__linux__)
    pocketFFT();
#else
    primitiveFFT();
#endif

    // Write magnitudes to output buffer
    int N = frame.size();
    int K = N / 2 + 1;
    magnitudes.resize(K, 0.0f);
    for (int k = 0; k < K; ++k) {
        magnitudes[k] = std::abs(spectrum[k]);
    }
}

// Primitive FFT (inefficient implementation)
void FourierTransformer::primitiveFFT() {
    int N = frame.size();
    if (N == 0) return;

    // Temporary complex buffer for full FFT
    std::vector<std::complex<float>> tempSpectrum(N, std::complex<float>(0.0f, 0.0f));

    // Copy frame to complex buffer
    for (int n = 0; n < N; ++n) {
        tempSpectrum[n] = std::complex<float>(frame[n], 0.0f);
    }

    // Bit-reversal permutation
    int bits = 0;
    for (int temp = N; temp > 1; temp >>= 1) ++bits;
    for (int i = 0; i < N; ++i) {
        int j = 0;
        for (int k = 0; k < bits; ++k) {
            if (i & (1 << k)) j |= 1 << (bits - 1 - k);
        }
        if (i < j) std::swap(tempSpectrum[i], tempSpectrum[j]);
    }

    // Iterative Cooley-Tukey radix-2 DIT FFT
    for (int s = 1; (1 << s) <= N; ++s) {
        int m = 1 << s;
        float theta = -2.0f * static_cast<float>(M_PI) / m;
        std::complex<float> wm = std::polar(1.0f, theta);
        for (int k = 0; k < N; k += m) {
            std::complex<float> w = 1.0f;
            for (int j = 0; j < m / 2; ++j) {
                std::complex<float> t = w * tempSpectrum[k + j + m / 2];
                std::complex<float> u = tempSpectrum[k + j];
                tempSpectrum[k + j] = u + t;
                tempSpectrum[k + j + m / 2] = u - t;
                w *= wm;
            }
        }
    }

    // Only keep first N/2+1 bins (DC, positive freqs, Nyquist)
    spectrum.resize(N / 2 + 1);
    for (int k = 0; k <= N / 2; ++k) {
        spectrum[k] = tempSpectrum[k];
    }
}

// Apple's Accelerate framework FFT implementation
#if defined(__APPLE__)
void FourierTransformer::accelerateFFT() {
    int N = frame.size();
    if (N == 0) return;

    int log2N = 0;
    int temp = N;
    while (temp >>= 1) ++log2N;

    if (!fftSetup || log2N != static_cast<int>(std::log2(real.size()))) {
        if (fftSetup) vDSP_destroy_fftsetup(fftSetup);
        fftSetup = vDSP_create_fftsetup(log2N, kFFTRadix2);
    }

    // Reuse preallocated buffers
    std::copy(frame.begin(), frame.end(), real.begin());
    std::fill(imag.begin(), imag.end(), 0.0f);

    DSPSplitComplex splitComplex;
    splitComplex.realp = real.data();
    splitComplex.imagp = imag.data();

    vDSP_ctoz(reinterpret_cast<const DSPComplex*>(frame.data()), 2, &splitComplex, 1, N / 2);

    vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2N, FFT_FORWARD);

    spectrum.resize(N / 2 + 1);
    spectrum[0] = std::complex<float>(splitComplex.realp[0], 0.0f);
    for (int k = 1; k < N / 2; ++k) {
        spectrum[k] = std::complex<float>(splitComplex.realp[k], splitComplex.imagp[k]);
    }
    spectrum[N / 2] = std::complex<float>(splitComplex.imagp[0], 0.0f);
}

#elif defined(__ANDROID__) || defined(__linux__)
void FourierTransformer::pocketFFT() {
    int N = frame.size();
    if (N == 0) return;

    // adjust input shape (length) and output (spectrum) size to the current input (frame) size
    // input of length N produces output of length N/2 + 1 for real-to-complex FFT
    input_shape[0] = N;
    spectrum.resize(N/2 + 1);

    pocketfft::r2c<float>(input_shape, input_stride, output_stride, 0, pocketfft::FORWARD, frame.data(), spectrum.data(), 1.0f);
}

#endif

