// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include <complex>
#include <vector>

#include <fftw3.h>

/**
 * Monophonic pitch detector based on the YIN algorithm
 * (de Cheveigné & Kawahara, 2002). The difference function is
 * computed through an FFT autocorrelation, so an 8192-sample window
 * costs a couple of FFTs instead of O(N²) work.
 */
class PitchDetector
{
public:
    struct Result {
        double frequency = 0.0; ///< Hz, 0 when no pitch was found
        double clarity = 0.0;   ///< 0..1, 1 means perfectly periodic
        double rms = 0.0;       ///< linear RMS of the analysed window
    };

    PitchDetector(int windowSize, double sampleRate);
    ~PitchDetector();

    PitchDetector(const PitchDetector &) = delete;
    PitchDetector &operator=(const PitchDetector &) = delete;

    int windowSize() const
    {
        return m_size;
    }

    void setFrequencyRange(double minHz, double maxHz);

    /// @p samples must hold windowSize() values.
    Result analyse(const float *samples);

private:
    int m_size;
    int m_half;
    double m_rate;
    int m_tauMin = 2;
    int m_tauMax = 2;

    float *m_signal;
    float *m_kernel;
    float *m_corr;
    fftwf_complex *m_signalSpec;
    fftwf_complex *m_kernelSpec;
    fftwf_plan m_signalPlan;
    fftwf_plan m_kernelPlan;
    fftwf_plan m_inversePlan;

    std::vector<double> m_prefixEnergy;
    std::vector<double> m_diff;
    std::vector<double> m_raw;
};
