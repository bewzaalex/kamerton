// SPDX-License-Identifier: GPL-3.0-or-later

#include "audioengine.h"

#include <KLocalizedString>

#include <QMetaObject>

#include <algorithm>
#include <cstring>

#include <spa/param/audio/format-utils.h>
#include <spa/pod/builder.h>

namespace
{
const char *nodeDescription(const spa_dict *props)
{
    for (const char *key : {PW_KEY_NODE_DESCRIPTION, PW_KEY_NODE_NICK, PW_KEY_NODE_NAME}) {
        if (const char *v = spa_dict_lookup(props, key)) {
            return v;
        }
    }
    return nullptr;
}
}

AudioEngine::AudioEngine(QObject *parent)
    : QObject(parent)
    , m_ring(RingSize, 0.0f)
{
    pw_init(nullptr, nullptr);

    m_capture.engine = this;
    m_playback.engine = this;

    m_loop = pw_thread_loop_new("kamerton-audio", nullptr);
    if (!m_loop) {
        return;
    }
    m_context = pw_context_new(pw_thread_loop_get_loop(m_loop), nullptr, 0);
    if (!m_context) {
        return;
    }
    if (pw_thread_loop_start(m_loop) < 0) {
        return;
    }

    pw_thread_loop_lock(m_loop);
    m_core = pw_context_connect(m_context, nullptr, 0);
    if (m_core) {
        static const pw_registry_events registryEvents = [] {
            pw_registry_events e{};
            e.version = PW_VERSION_REGISTRY_EVENTS;
            e.global = &AudioEngine::onRegistryGlobal;
            e.global_remove = &AudioEngine::onRegistryGlobalRemove;
            return e;
        }();
        m_registry = pw_core_get_registry(m_core, PW_VERSION_REGISTRY, 0);
        pw_registry_add_listener(m_registry, &m_registryListener, &registryEvents, this);
    }
    pw_thread_loop_unlock(m_loop);
}

AudioEngine::~AudioEngine()
{
    if (m_loop) {
        pw_thread_loop_lock(m_loop);
        destroyStream(m_capture);
        destroyStream(m_playback);
        if (m_registry) {
            spa_hook_remove(&m_registryListener);
            pw_proxy_destroy(reinterpret_cast<pw_proxy *>(m_registry));
        }
        if (m_core) {
            pw_core_disconnect(m_core);
        }
        pw_thread_loop_unlock(m_loop);
        pw_thread_loop_stop(m_loop);
        if (m_context) {
            pw_context_destroy(m_context);
        }
        pw_thread_loop_destroy(m_loop);
    }
    pw_deinit();
}

void AudioEngine::setCaptureEnabled(bool enabled)
{
    if (!m_core) {
        return;
    }
    pw_thread_loop_lock(m_loop);
    if (enabled && !m_capture.stream) {
        createCapture();
    } else if (!enabled) {
        destroyStream(m_capture);
    }
    pw_thread_loop_unlock(m_loop);
}

void AudioEngine::setPlaybackEnabled(bool enabled)
{
    m_generator.setActive(enabled);
    if (!m_core) {
        return;
    }
    pw_thread_loop_lock(m_loop);
    if (enabled && !m_playback.stream) {
        createPlayback();
    } else if (!enabled) {
        destroyStream(m_playback);
    }
    pw_thread_loop_unlock(m_loop);
}

void AudioEngine::setInputTarget(const QString &nodeName)
{
    if (m_inputTarget == nodeName) {
        return;
    }
    m_inputTarget = nodeName;
    if (!m_core) {
        return;
    }
    pw_thread_loop_lock(m_loop);
    if (m_capture.stream) {
        destroyStream(m_capture);
        createCapture();
    }
    pw_thread_loop_unlock(m_loop);
}

void AudioEngine::setOutputTarget(const QString &nodeName)
{
    if (m_outputTarget == nodeName) {
        return;
    }
    m_outputTarget = nodeName;
    if (!m_core) {
        return;
    }
    pw_thread_loop_lock(m_loop);
    if (m_playback.stream) {
        destroyStream(m_playback);
        createPlayback();
    }
    pw_thread_loop_unlock(m_loop);
}

bool AudioEngine::latestSamples(float *dst, int count) const
{
    const quint64 end = m_writePos.load(std::memory_order_acquire);
    if (end < quint64(count) || quint64(count) > RingSize / 2) {
        return false;
    }
    const quint64 start = end - count;
    for (int i = 0; i < count; ++i) {
        dst[i] = m_ring[(start + i) & (RingSize - 1)];
    }
    return true;
}

// Must be called with the thread loop locked.
void AudioEngine::createCapture()
{
    static const pw_stream_events events = [] {
        pw_stream_events e{};
        e.version = PW_VERSION_STREAM_EVENTS;
        e.process = &AudioEngine::onCaptureProcess;
        e.state_changed = &AudioEngine::onStreamStateChanged;
        return e;
    }();

    pw_properties *props = pw_properties_new(PW_KEY_MEDIA_TYPE,
                                             "Audio",
                                             PW_KEY_MEDIA_CATEGORY,
                                             "Capture",
                                             PW_KEY_MEDIA_ROLE,
                                             "Production",
                                             PW_KEY_APP_NAME,
                                             "Kamerton",
                                             PW_KEY_APP_ICON_NAME,
                                             "io.github.bewzaalex.kamerton",
                                             PW_KEY_NODE_NAME,
                                             "kamerton-input",
                                             PW_KEY_NODE_DESCRIPTION,
                                             "Kamerton tuner input",
                                             PW_KEY_NODE_LATENCY,
                                             "512/48000",
                                             nullptr);
    if (!m_inputTarget.isEmpty()) {
        pw_properties_set(props, PW_KEY_TARGET_OBJECT, m_inputTarget.toUtf8().constData());
    }

    m_capture.stream = pw_stream_new(m_core, "Kamerton input", props);
    if (!m_capture.stream) {
        return;
    }
    pw_stream_add_listener(m_capture.stream, &m_capture.listener, &events, &m_capture);

    uint8_t buffer[1024];
    spa_pod_builder b{};
    spa_pod_builder_init(&b, buffer, sizeof(buffer));
    spa_audio_info_raw info{};
    info.format = SPA_AUDIO_FORMAT_F32;
    info.channels = 1;
    info.rate = SampleRate;
    info.position[0] = SPA_AUDIO_CHANNEL_MONO;
    const spa_pod *params[1] = {spa_format_audio_raw_build(&b, SPA_PARAM_EnumFormat, &info)};

    pw_stream_connect(m_capture.stream,
                      PW_DIRECTION_INPUT,
                      PW_ID_ANY,
                      pw_stream_flags(PW_STREAM_FLAG_AUTOCONNECT | PW_STREAM_FLAG_MAP_BUFFERS | PW_STREAM_FLAG_RT_PROCESS),
                      params,
                      1);
}

// Must be called with the thread loop locked.
void AudioEngine::createPlayback()
{
    static const pw_stream_events events = [] {
        pw_stream_events e{};
        e.version = PW_VERSION_STREAM_EVENTS;
        e.process = &AudioEngine::onPlaybackProcess;
        e.state_changed = &AudioEngine::onStreamStateChanged;
        return e;
    }();

    pw_properties *props = pw_properties_new(PW_KEY_MEDIA_TYPE,
                                             "Audio",
                                             PW_KEY_MEDIA_CATEGORY,
                                             "Playback",
                                             PW_KEY_MEDIA_ROLE,
                                             "Music",
                                             PW_KEY_APP_NAME,
                                             "Kamerton",
                                             PW_KEY_APP_ICON_NAME,
                                             "io.github.bewzaalex.kamerton",
                                             PW_KEY_NODE_NAME,
                                             "kamerton-reference",
                                             PW_KEY_NODE_DESCRIPTION,
                                             "Kamerton reference tone",
                                             PW_KEY_NODE_LATENCY,
                                             "1024/48000",
                                             nullptr);
    if (!m_outputTarget.isEmpty()) {
        pw_properties_set(props, PW_KEY_TARGET_OBJECT, m_outputTarget.toUtf8().constData());
    }

    m_playback.stream = pw_stream_new(m_core, "Kamerton reference tone", props);
    if (!m_playback.stream) {
        return;
    }
    pw_stream_add_listener(m_playback.stream, &m_playback.listener, &events, &m_playback);

    uint8_t buffer[1024];
    spa_pod_builder b{};
    spa_pod_builder_init(&b, buffer, sizeof(buffer));
    spa_audio_info_raw info{};
    info.format = SPA_AUDIO_FORMAT_F32;
    info.channels = 2;
    info.rate = SampleRate;
    info.position[0] = SPA_AUDIO_CHANNEL_FL;
    info.position[1] = SPA_AUDIO_CHANNEL_FR;
    const spa_pod *params[1] = {spa_format_audio_raw_build(&b, SPA_PARAM_EnumFormat, &info)};

    pw_stream_connect(m_playback.stream,
                      PW_DIRECTION_OUTPUT,
                      PW_ID_ANY,
                      pw_stream_flags(PW_STREAM_FLAG_AUTOCONNECT | PW_STREAM_FLAG_MAP_BUFFERS | PW_STREAM_FLAG_RT_PROCESS),
                      params,
                      1);
}

// Must be called with the thread loop locked.
void AudioEngine::destroyStream(StreamCtx &ctx)
{
    if (ctx.stream) {
        pw_stream_destroy(ctx.stream);
        ctx.stream = nullptr;
        ctx.listener = spa_hook{};
    }
}

void AudioEngine::onCaptureProcess(void *data)
{
    auto *ctx = static_cast<StreamCtx *>(data);
    AudioEngine *self = ctx->engine;
    pw_buffer *b = pw_stream_dequeue_buffer(ctx->stream);
    if (!b) {
        return;
    }
    spa_buffer *buf = b->buffer;
    const auto *samples = static_cast<const float *>(buf->datas[0].data);
    if (samples && buf->datas[0].chunk) {
        const uint32_t offset = std::min(buf->datas[0].chunk->offset, buf->datas[0].maxsize);
        const uint32_t size = std::min(buf->datas[0].chunk->size, buf->datas[0].maxsize - offset);
        samples = reinterpret_cast<const float *>(reinterpret_cast<const uint8_t *>(samples) + offset);
        const uint32_t n = size / sizeof(float);

        const quint64 w = self->m_writePos.load(std::memory_order_relaxed);
        for (uint32_t i = 0; i < n; ++i) {
            self->m_ring[(w + i) & (RingSize - 1)] = samples[i];
        }
        self->m_writePos.store(w + n, std::memory_order_release);
    }
    pw_stream_queue_buffer(ctx->stream, b);
}

void AudioEngine::onPlaybackProcess(void *data)
{
    auto *ctx = static_cast<StreamCtx *>(data);
    pw_buffer *b = pw_stream_dequeue_buffer(ctx->stream);
    if (!b) {
        return;
    }
    spa_buffer *buf = b->buffer;
    auto *dst = static_cast<float *>(buf->datas[0].data);
    if (dst) {
        constexpr uint32_t channels = 2;
        constexpr uint32_t stride = sizeof(float) * channels;
        uint32_t frames = buf->datas[0].maxsize / stride;
        if (b->requested) {
            frames = std::min<uint32_t>(frames, uint32_t(b->requested));
        }
        ctx->engine->m_generator.render(dst, frames, channels);
        buf->datas[0].chunk->offset = 0;
        buf->datas[0].chunk->stride = stride;
        buf->datas[0].chunk->size = frames * stride;
    }
    pw_stream_queue_buffer(ctx->stream, b);
}

void AudioEngine::onStreamStateChanged(void *data, pw_stream_state, pw_stream_state state, const char *error)
{
    auto *ctx = static_cast<StreamCtx *>(data);
    if (state == PW_STREAM_STATE_ERROR) {
        const QString message = i18n("Audio stream error: %1", QString::fromUtf8(error ? error : "unknown"));
        AudioEngine *self = ctx->engine;
        QMetaObject::invokeMethod(
            self,
            [self, message] {
                Q_EMIT self->errorOccurred(message);
            },
            Qt::QueuedConnection);
    }
}

void AudioEngine::onRegistryGlobal(void *data, uint32_t id, uint32_t, const char *type, uint32_t, const spa_dict *props)
{
    auto *self = static_cast<AudioEngine *>(data);
    if (!props || std::strcmp(type, PW_TYPE_INTERFACE_Node) != 0) {
        return;
    }
    const char *mediaClass = spa_dict_lookup(props, PW_KEY_MEDIA_CLASS);
    const char *name = spa_dict_lookup(props, PW_KEY_NODE_NAME);
    if (!mediaClass || !name) {
        return;
    }
    const bool isSource = std::strncmp(mediaClass, "Audio/Source", 12) == 0;
    const bool isSink = std::strcmp(mediaClass, "Audio/Sink") == 0;
    if (!isSource && !isSink) {
        return;
    }
    const char *desc = nodeDescription(props);
    self->m_nodes[id] = NodeInfo{isSource, Device{QString::fromUtf8(name), QString::fromUtf8(desc ? desc : name)}};
    self->publishDevices();
}

void AudioEngine::onRegistryGlobalRemove(void *data, uint32_t id)
{
    auto *self = static_cast<AudioEngine *>(data);
    if (self->m_nodes.erase(id) > 0) {
        self->publishDevices();
    }
}

// Runs on the PipeWire thread; hands a snapshot over to the GUI thread.
void AudioEngine::publishDevices()
{
    QList<Device> inputs;
    QList<Device> outputs;
    for (const auto &[id, node] : m_nodes) {
        (node.isSource ? inputs : outputs).append(node.device);
    }
    auto byLabel = [](const Device &a, const Device &b) {
        return a.description.localeAwareCompare(b.description) < 0;
    };
    std::sort(inputs.begin(), inputs.end(), byLabel);
    std::sort(outputs.begin(), outputs.end(), byLabel);

    QMetaObject::invokeMethod(
        this,
        [this, inputs, outputs] {
            m_inputs = inputs;
            m_outputs = outputs;
            Q_EMIT devicesChanged();
        },
        Qt::QueuedConnection);
}
