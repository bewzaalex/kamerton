// SPDX-License-Identifier: GPL-3.0-or-later

#include "tonegenerator.h"

#include <cmath>
#include <numbers>

namespace
{
// Relative harmonic amplitudes for each timbre.
constexpr double PluckAmps[ToneGenerator::MaxHarmonics] = {1.0, 0.55, 0.38, 0.26, 0.18, 0.13, 0.09, 0.06, 0.04, 0.03};
constexpr double OrganAmps[ToneGenerator::MaxHarmonics] = {1.0, 0.5, 0.3, 0.15, 0.08, 0.0, 0.0, 0.0, 0.0, 0.0};
constexpr double SineAmps[ToneGenerator::MaxHarmonics] = {1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0};

double ampSum(const double *amps)
{
    double s = 0.0;
    for (int h = 0; h < ToneGenerator::MaxHarmonics; ++h) {
        s += amps[h];
    }
    return s;
}
}

ToneGenerator::ToneGenerator(double sampleRate)
    : m_rate(sampleRate)
{
}

void ToneGenerator::setSampleRate(double rate)
{
    m_rate = rate;
}

void ToneGenerator::setFrequency(double hz)
{
    m_frequency = hz;
}

void ToneGenerator::setTimbre(Timbre timbre)
{
    m_timbre = timbre;
}

void ToneGenerator::setVolume(double volume)
{
    m_volume = volume;
}

void ToneGenerator::setActive(bool active)
{
    m_active = active;
}

void ToneGenerator::trigger()
{
    m_triggerCount.fetch_add(1);
}

void ToneGenerator::render(float *out, uint32_t frames, uint32_t channels)
{
    const double rate = m_rate.load();
    const double freq = m_frequency.load();
    const int timbre = m_timbre.load();
    const double target = m_active.load() ? m_volume.load() * 0.35 : 0.0;

    const uint32_t trig = m_triggerCount.load();
    if (trig != m_seenTrigger) {
        m_seenTrigger = trig;
        m_noteTime = 0.0;
    }

    const double *amps = timbre == Organ ? OrganAmps : timbre == Sine ? SineAmps : PluckAmps;
    const double norm = 1.0 / ampSum(amps);
    const double nyquist = rate * 0.45;
    int harmonics = 0;
    while (harmonics < MaxHarmonics && freq * (harmonics + 1) < nyquist) {
        ++harmonics;
    }

    const double dt = 1.0 / rate;
    const double phaseInc = freq * dt;
    // ~5 ms smoothing on the master gain to avoid clicks.
    const double gainCoef = 1.0 - std::exp(-dt / 0.005);
    constexpr double twoPi = 2.0 * std::numbers::pi;

    for (uint32_t i = 0; i < frames; ++i) {
        m_gain += (target - m_gain) * gainCoef;

        double v = 0.0;
        if (m_gain > 1e-6) {
            for (int h = 0; h < harmonics; ++h) {
                double a = amps[h];
                if (a == 0.0) {
                    continue;
                }
                if (timbre == Pluck) {
                    // Higher partials die away faster, like a real string.
                    const double attack = std::min(1.0, m_noteTime / 0.004);
                    a *= attack * std::exp(-m_noteTime * (0.7 + 0.55 * h));
                }
                v += a * std::sin(twoPi * (h + 1) * m_phase);
            }
            v *= norm * m_gain;
        }

        m_phase += phaseInc;
        if (m_phase >= 1.0) {
            m_phase -= std::floor(m_phase);
        }
        m_noteTime += dt;

        for (uint32_t c = 0; c < channels; ++c) {
            out[i * channels + c] = float(v);
        }
    }
}
