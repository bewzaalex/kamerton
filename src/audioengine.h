// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include <QList>
#include <QObject>
#include <QString>
#include <QTimer>

#include <atomic>
#include <map>
#include <vector>

#include <pipewire/pipewire.h>

#include "tonegenerator.h"

/**
 * Talks to PipeWire directly: a mono capture stream that feeds a
 * lock-free ring buffer, a stereo playback stream driven by
 * ToneGenerator, and a registry listener that keeps the list of
 * audio sources and sinks up to date.
 *
 * Streams only exist while they are enabled: the playback stream is
 * created when a reference tone starts and destroyed once it has faded out.
 */
class AudioEngine : public QObject
{
    Q_OBJECT

public:
    static constexpr int SampleRate = 48000;

    struct Device {
        QString name;        ///< PipeWire node.name, used as target.object
        QString description; ///< human readable label
    };

    explicit AudioEngine(QObject *parent = nullptr);
    ~AudioEngine() override;

    bool isConnected() const
    {
        return m_core != nullptr;
    }

    QList<Device> inputDevices() const
    {
        return m_inputs;
    }
    QList<Device> outputDevices() const
    {
        return m_outputs;
    }

    void setCaptureEnabled(bool enabled);
    void setPlaybackEnabled(bool enabled);
    void setInputTarget(const QString &nodeName);
    void setOutputTarget(const QString &nodeName);

    ToneGenerator &generator()
    {
        return m_generator;
    }

    /// Total number of captured samples so far.
    quint64 samplesWritten() const
    {
        return m_writePos.load(std::memory_order_acquire);
    }

    /// Copies the most recent @p count samples. Returns false if fewer were captured.
    bool latestSamples(float *dst, int count) const;

Q_SIGNALS:
    void devicesChanged();
    void errorOccurred(const QString &message);

private:
    struct StreamCtx {
        AudioEngine *engine = nullptr;
        pw_stream *stream = nullptr;
        spa_hook listener{};
    };

    struct NodeInfo {
        bool isSource = false;
        Device device;
    };

    void createCapture();
    void createPlayback();
    void destroyStream(StreamCtx &ctx);
    void publishDevices();

    static void onCaptureProcess(void *data);
    static void onPlaybackProcess(void *data);
    static void onStreamStateChanged(void *data, pw_stream_state old, pw_stream_state state, const char *error);
    static void onRegistryGlobal(void *data, uint32_t id, uint32_t permissions, const char *type, uint32_t version, const spa_dict *props);
    static void onRegistryGlobalRemove(void *data, uint32_t id);

    pw_thread_loop *m_loop = nullptr;
    pw_context *m_context = nullptr;
    pw_core *m_core = nullptr;
    pw_registry *m_registry = nullptr;
    spa_hook m_registryListener{};

    StreamCtx m_capture;
    StreamCtx m_playback;
    QTimer m_playbackStop; ///< destroys the playback stream once the fade-out has finished
    QString m_inputTarget;
    QString m_outputTarget;

    ToneGenerator m_generator{SampleRate};

    // Single-producer (PipeWire RT thread) / single-consumer (GUI thread) ring.
    static constexpr quint64 RingSize = 1 << 15;
    std::vector<float> m_ring;
    std::atomic<quint64> m_writePos{0};

    // Owned by the PipeWire thread.
    std::map<uint32_t, NodeInfo> m_nodes;

    // Owned by the GUI thread.
    QList<Device> m_inputs;
    QList<Device> m_outputs;
};
