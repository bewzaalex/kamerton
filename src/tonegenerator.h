// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include <atomic>
#include <cstdint>

/**
 * Additive synthesiser for reference tones.
 *
 * Parameters are atomics so the GUI thread can change them while
 * render() runs on the PipeWire real-time thread.
 */
class ToneGenerator
{
public:
    enum Timbre {
        Pluck = 0,
        Sine,
        Organ,
    };

    static constexpr int MaxHarmonics = 10;

    explicit ToneGenerator(double sampleRate = 48000.0);

    void setSampleRate(double rate);
    void setFrequency(double hz);
    void setTimbre(Timbre timbre);
    void setVolume(double volume); ///< 0..1
    void setActive(bool active);

    /// Restart the note envelope (re-plucks a string).
    void trigger();

    /// Real-time safe. Writes @p frames frames of interleaved audio.
    void render(float *out, uint32_t frames, uint32_t channels);

private:
    std::atomic<double> m_rate;
    std::atomic<double> m_frequency{110.0};
    std::atomic<int> m_timbre{Pluck};
    std::atomic<double> m_volume{0.6};
    std::atomic<bool> m_active{false};
    std::atomic<uint32_t> m_triggerCount{0};

    // Render-thread state.
    uint32_t m_seenTrigger = 0;
    double m_phase = 0.0;
    double m_noteTime = 0.0;
    double m_gain = 0.0;
};
