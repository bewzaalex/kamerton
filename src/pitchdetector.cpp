// SPDX-License-Identifier: GPL-3.0-or-later

#include "pitchdetector.h"

#include <algorithm>
#include <cmath>

namespace
{
constexpr double YinThreshold = 0.12;
constexpr double YinFallbackThreshold = 0.35;
}

PitchDetector::PitchDetector(int windowSize, double sampleRate)
    : m_size(windowSize)
    , m_half(windowSize / 2)
    , m_rate(sampleRate)
{
    const int bins = m_size / 2 + 1;
    m_signal = fftwf_alloc_real(m_size);
    m_kernel = fftwf_alloc_real(m_size);
    m_corr = fftwf_alloc_real(m_size);
    m_signalSpec = fftwf_alloc_complex(bins);
    m_kernelSpec = fftwf_alloc_complex(bins);

    m_signalPlan = fftwf_plan_dft_r2c_1d(m_size, m_signal, m_signalSpec, FFTW_ESTIMATE);
    m_kernelPlan = fftwf_plan_dft_r2c_1d(m_size, m_kernel, m_kernelSpec, FFTW_ESTIMATE);
    m_inversePlan = fftwf_plan_dft_c2r_1d(m_size, m_signalSpec, m_corr, FFTW_ESTIMATE);

    m_prefixEnergy.resize(m_size + 1);
    m_diff.resize(m_half);
    m_raw.resize(m_half);

    setFrequencyRange(25.0, 2000.0);
}

PitchDetector::~PitchDetector()
{
    fftwf_destroy_plan(m_signalPlan);
    fftwf_destroy_plan(m_kernelPlan);
    fftwf_destroy_plan(m_inversePlan);
    fftwf_free(m_signal);
    fftwf_free(m_kernel);
    fftwf_free(m_corr);
    fftwf_free(m_signalSpec);
    fftwf_free(m_kernelSpec);
}

void PitchDetector::setFrequencyRange(double minHz, double maxHz)
{
    m_tauMin = std::max(2, int(std::floor(m_rate / maxHz)));
    m_tauMax = std::min(m_half - 2, int(std::ceil(m_rate / minHz)));
}

PitchDetector::Result PitchDetector::analyse(const float *samples)
{
    Result result;

    // Remove DC offset and measure level.
    double mean = 0.0;
    for (int i = 0; i < m_size; ++i) {
        mean += samples[i];
    }
    mean /= m_size;

    double energy = 0.0;
    m_prefixEnergy[0] = 0.0;
    for (int i = 0; i < m_size; ++i) {
        const float v = float(samples[i] - mean);
        m_signal[i] = v;
        m_kernel[i] = i < m_half ? v : 0.0f;
        energy += double(v) * v;
        m_prefixEnergy[i + 1] = energy;
    }
    result.rms = std::sqrt(energy / m_size);
    if (result.rms < 1e-6) {
        return result;
    }

    // Cross-correlation c(tau) = sum_{j<half} x[j] * x[j + tau] via FFT.
    // The kernel is zero beyond half, so the circular correlation never wraps for tau < half.
    fftwf_execute(m_signalPlan);
    fftwf_execute(m_kernelPlan);
    const int bins = m_size / 2 + 1;
    for (int k = 0; k < bins; ++k) {
        const std::complex<float> s(m_signalSpec[k][0], m_signalSpec[k][1]);
        const std::complex<float> kk(m_kernelSpec[k][0], m_kernelSpec[k][1]);
        const std::complex<float> p = std::conj(kk) * s;
        m_signalSpec[k][0] = p.real();
        m_signalSpec[k][1] = p.imag();
    }
    fftwf_execute(m_inversePlan);
    const double norm = 1.0 / m_size;

    // YIN difference function d(tau) = e(0..half) + e(tau..tau+half) - 2 c(tau),
    // then the cumulative mean normalised difference d'(tau).
    const double e0 = m_prefixEnergy[m_half];
    m_diff[0] = 1.0;
    double running = 0.0;
    for (int tau = 1; tau <= m_tauMax + 1 && tau < m_half; ++tau) {
        const double et = m_prefixEnergy[tau + m_half] - m_prefixEnergy[tau];
        const double d = std::max(0.0, e0 + et - 2.0 * m_corr[tau] * norm);
        m_raw[tau] = d;
        running += d;
        m_diff[tau] = running > 0.0 ? d * tau / running : 1.0;
    }

    // Absolute threshold: take the first dip under the threshold, then walk to its minimum.
    int best = -1;
    for (int tau = m_tauMin; tau <= m_tauMax; ++tau) {
        if (m_diff[tau] < YinThreshold) {
            while (tau + 1 <= m_tauMax && m_diff[tau + 1] < m_diff[tau]) {
                ++tau;
            }
            best = tau;
            break;
        }
    }
    if (best < 0) {
        // No confident dip: fall back to the global minimum when it is still reasonably periodic.
        int minTau = m_tauMin;
        for (int tau = m_tauMin + 1; tau <= m_tauMax; ++tau) {
            if (m_diff[tau] < m_diff[minTau]) {
                minTau = tau;
            }
        }
        if (m_diff[minTau] >= YinFallbackThreshold) {
            return result;
        }
        best = minTau;
    }

    // Parabolic interpolation around the minimum for sub-sample precision. The raw
    // difference function is used: the cumulative normalisation skews the parabola.
    double refined = best;
    if (best > 1 && best < m_tauMax) {
        const double a = m_raw[best - 1];
        const double b = m_raw[best];
        const double c = m_raw[best + 1];
        const double denom = a - 2.0 * b + c;
        if (std::abs(denom) > 1e-12) {
            refined = best + 0.5 * (a - c) / denom;
        }
    }

    result.frequency = m_rate / refined;
    result.clarity = std::clamp(1.0 - m_diff[best], 0.0, 1.0);
    return result;
}
