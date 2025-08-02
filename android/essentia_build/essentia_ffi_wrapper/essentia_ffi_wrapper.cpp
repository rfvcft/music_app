#include <essentia/algorithmfactory.h>
#include <essentia/essentia.h>
#include <cmath>

extern "C" {

// TODO: remove later, this is only for testing purposes
float compute_rms(const float* data, int length) {
    float sum = 0.0;
    for (int i = 0; i < length; ++i) {
        sum += data[i] * data[i];
    }
    return std::sqrt(sum / length);
}

void init_essentia() {
    essentia::init();
}

}
