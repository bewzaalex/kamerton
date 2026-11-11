// SPDX-License-Identifier: GPL-3.0-or-later

#include "tunercontroller.h"

#include "audioengine.h"

#include <KConfigGroup>
#include <KLocalizedString>

#include <QVariantMap>

#include <algorithm>
#include <cmath>

namespace
{
constexpr int AnalysisIntervalMs = 33;
constexpr int ReferenceIntervalMs = 2500;
constexpr int SignalHoldMs = 450;
constexpr int MedianLength = 5;
constexpr double MinClarity = 0.80;
constexpr int StringSwitchFrames = 3;
constexpr int TunedAfterFrames = 14; // ~0.45 s steady in tune

QString formatNotes(const QList<int> &notes)
{
    QStringList names;
    for (int n : notes) {
        names.append(Notes::name(n));
    }
    return names.join(QLatin1Char(' '));
}
}

TunerController::TunerController(QObject *parent)
    : QObject(parent)
    , m_engine(std::make_unique<AudioEngine>())
    , m_detector(WindowSize, AudioEngine::SampleRate)
    , m_window(WindowSize)
    , m_config(KSharedConfig::openConfig())
    , m_instruments(Instruments::builtin())
{
    loadCustomTunings();
    loadSettings();

    if (!m_engine->isConnected()) {
        m_audioError = i18n("Could not connect to PipeWire. Is the PipeWire service running?");
    }

    connect(m_engine.get(), &AudioEngine::devicesChanged, this, &TunerController::devicesChanged);
    connect(m_engine.get(), &AudioEngine::errorOccurred, this, [this](const QString &message) {
        m_audioError = message;
        Q_EMIT audioErrorChanged();
    });

    m_analysisTimer.setInterval(AnalysisIntervalMs);
    connect(&m_analysisTimer, &QTimer::timeout, this, &TunerController::analyse);
    m_referenceTimer.setInterval(ReferenceIntervalMs);
    connect(&m_referenceTimer, &QTimer::timeout, this, &TunerController::onReferenceTick);

    m_engine->setInputTarget(m_inputDevice);
    m_engine->setOutputTarget(m_outputDevice);
    m_engine->generator().setVolume(m_volume / 100.0);
    m_engine->generator().setTimbre(ToneGenerator::Timbre(m_timbre));

    updateDetectorRange();
    clearMeasurement();

    // The microphone is always listening; the reference tone plays on top of it.
    m_engine->setCaptureEnabled(true);
    m_analysisTimer.start();
}

TunerController::~TunerController()
{
    m_analysisTimer.stop();
    m_referenceTimer.stop();
    m_config->sync();
}

KConfigGroup TunerController::generalGroup() const
{
    return m_config->group(QStringLiteral("General"));
}

void TunerController::loadSettings()
{
    const KConfigGroup g = generalGroup();

    const QString instrumentId = g.readEntry("Instrument", QStringLiteral("guitar6"));
    for (int i = 0; i < m_instruments.size(); ++i) {
        if (m_instruments[i].id == instrumentId) {
            m_instrument = i;
            break;
        }
    }
    const QString tuningName = g.readEntry("Tuning", QString());
    const auto &tunings = currentInstrument().tunings;
    for (int i = 0; i < tunings.size(); ++i) {
        if (tunings[i].name == tuningName) {
            m_tuning = i;
            break;
        }
    }

    m_autoDetect = g.readEntry("AutoDetect", true);
    m_displayStyle = DisplayStyle(std::clamp(g.readEntry("DisplayStyle", int(Needle)), int(Needle), int(Bar)));
    m_a4 = std::clamp(g.readEntry("A4", 440), 400, 480);
    m_inTuneThreshold = std::clamp(g.readEntry("InTuneThreshold", 3.0), 0.5, 10.0);
    m_noiseGate = std::clamp(g.readEntry("NoiseGate", -55), -90, -10);
    m_timbre = Timbre(std::clamp(g.readEntry("Timbre", int(Pluck)), int(Pluck), int(Organ)));
    m_volume = std::clamp(g.readEntry("Volume", 60), 0, 100);
    m_cycleStrings = g.readEntry("CycleStrings", false);
    m_inputDevice = g.readEntry("InputDevice", QString());
    m_outputDevice = g.readEntry("OutputDevice", QString());

    m_tuned = QList<bool>(currentNotes().size(), false);
}

void TunerController::loadCustomTunings()
{
    const KConfigGroup g = m_config->group(QStringLiteral("CustomTunings"));
    for (Instrument &inst : m_instruments) {
        const QStringList entries = g.readEntry(inst.id, QStringList());
        for (const QString &entry : entries) {
            const qsizetype sep = entry.lastIndexOf(QLatin1Char('|'));
            if (sep <= 0) {
                continue;
            }
            const auto notes = Notes::parseList(entry.mid(sep + 1));
            if (notes && !notes->isEmpty()) {
                inst.tunings.append(Tuning{entry.left(sep), *notes, true});
            }
        }
    }
}

void TunerController::saveCustomTunings()
{
    KConfigGroup g = m_config->group(QStringLiteral("CustomTunings"));
    for (const Instrument &inst : std::as_const(m_instruments)) {
        QStringList entries;
        for (const Tuning &t : inst.tunings) {
            if (!t.custom) {
                continue;
            }
            QStringList names;
            for (int n : t.notes) {
                names.append(Notes::asciiName(n));
            }
            entries.append(t.name + QLatin1Char('|') + names.join(QLatin1Char(' ')));
        }
        if (entries.isEmpty()) {
            g.deleteEntry(inst.id);
        } else {
            g.writeEntry(inst.id, entries);
        }
    }
    m_config->sync();
}

const Instrument &TunerController::currentInstrument() const
{
    return m_instruments.at(m_instrument);
}

const Tuning &TunerController::currentTuning() const
{
    const auto &tunings = currentInstrument().tunings;
    return tunings.at(std::clamp(m_tuning, 0, int(tunings.size()) - 1));
}

QList<int> TunerController::currentNotes() const
{
    return currentTuning().notes;
}

// ---------------------------------------------------------------------------
// Instrument and tuning

QVariantList TunerController::instruments() const
{
    QVariantList list;
    for (const Instrument &inst : m_instruments) {
        list.append(QVariantMap{
            {QStringLiteral("name"), inst.name},
            {QStringLiteral("variant"), inst.variant},
            {QStringLiteral("group"), inst.group},
            {QStringLiteral("stringCount"), inst.isChromatic() ? 0 : int(inst.tunings.constFirst().notes.size())},
        });
    }
    return list;
}

void TunerController::setInstrumentIndex(int index)
{
    if (index < 0 || index >= m_instruments.size() || index == m_instrument) {
        return;
    }
    m_instrument = index;
    m_tuning = 0;
    m_selected = 0;
    m_tuned = QList<bool>(currentNotes().size(), false);
    generalGroup().writeEntry("Instrument", currentInstrument().id);
    generalGroup().writeEntry("Tuning", currentTuning().name);

    clearMeasurement();
    updateDetectorRange();
    Q_EMIT instrumentChanged();
    Q_EMIT referenceAvailableChanged();
    if (!referenceAvailable()) {
        setPlaying(false);
    }
    Q_EMIT tuningsChanged();
    Q_EMIT tuningChanged();
    Q_EMIT stringsChanged();
    Q_EMIT selectedStringChanged();
    Q_EMIT referenceChanged();
    updateTone(true);
}

QString TunerController::instrumentName() const
{
    return currentInstrument().name;
}

QString TunerController::instrumentVariant() const
{
    return currentInstrument().variant;
}

int TunerController::headLeft() const
{
    return currentInstrument().headLeft;
}

int TunerController::headRight() const
{
    return currentInstrument().headRight;
}

bool TunerController::isChromatic() const
{
    return currentNotes().isEmpty();
}

QVariantList TunerController::tunings() const
{
    QVariantList list;
    for (const Tuning &t : currentInstrument().tunings) {
        list.append(QVariantMap{
            {QStringLiteral("name"), t.name},
            {QStringLiteral("notes"), formatNotes(t.notes)},
            {QStringLiteral("custom"), t.custom},
        });
    }
    return list;
}

void TunerController::setTuningIndex(int index)
{
    if (index < 0 || index >= currentInstrument().tunings.size() || index == m_tuning) {
        return;
    }
    m_tuning = index;
    const int count = int(currentNotes().size());
    m_selected = std::min(m_selected, std::max(0, count - 1));
    m_tuned = QList<bool>(count, false);
    generalGroup().writeEntry("Tuning", currentTuning().name);

    clearMeasurement();
    updateDetectorRange();
    Q_EMIT tuningChanged();
    Q_EMIT stringsChanged();
    Q_EMIT selectedStringChanged();
    Q_EMIT referenceChanged();
    updateTone(true);
}

QString TunerController::tuningName() const
{
    return currentTuning().name;
}

QString TunerController::tuningNotes() const
{
    QStringList letters;
    for (int n : currentNotes()) {
        letters.append(Notes::letter(n));
    }
    return letters.join(QLatin1Char(' '));
}

QVariantList TunerController::strings() const
{
    QVariantList list;
    const QList<int> notes = currentNotes();
    for (int i = 0; i < notes.size(); ++i) {
        list.append(QVariantMap{
            {QStringLiteral("letter"), Notes::letter(notes[i])},
            {QStringLiteral("octave"), Notes::octave(notes[i])},
            {QStringLiteral("frequency"), Notes::frequency(notes[i], m_a4)},
            {QStringLiteral("number"), int(notes.size()) - i},
            {QStringLiteral("tuned"), i < m_tuned.size() && m_tuned[i]},
        });
    }
    return list;
}

void TunerController::setSelectedString(int index)
{
    if (index < 0 || index >= currentNotes().size()) {
        return;
    }
    if (index != m_selected) {
        m_selected = index;
        Q_EMIT selectedStringChanged();
        Q_EMIT referenceChanged();
    }
    if (!m_autoDetect) {
        m_activeString = index;
        Q_EMIT measurementChanged();
    }
    updateTone(true);
}

void TunerController::setAutoDetect(bool enabled)
{
    if (m_autoDetect == enabled) {
        return;
    }
    m_autoDetect = enabled;
    generalGroup().writeEntry("AutoDetect", enabled);
    if (enabled) {
        setPlaying(false);
    } else {
        m_activeString = m_selected;
        Q_EMIT measurementChanged();
    }
    Q_EMIT autoDetectChanged();
    Q_EMIT referenceAvailableChanged();
}

int TunerController::tunedCount() const
{
    return int(std::count(m_tuned.cbegin(), m_tuned.cend(), true));
}

void TunerController::resetTuned()
{
    m_tuned = QList<bool>(currentNotes().size(), false);
    Q_EMIT stringsChanged();
}

// ---------------------------------------------------------------------------
// Measurement

QString TunerController::noteLetter() const
{
    return Notes::letter(m_nearestMidi);
}

int TunerController::noteOctave() const
{
    return Notes::octave(m_nearestMidi);
}

double TunerController::targetFrequency() const
{
    return Notes::frequency(m_nearestMidi, m_a4);
}

bool TunerController::inTune() const
{
    return m_hasSignal && std::abs(m_cents) <= m_inTuneThreshold;
}

void TunerController::updateDetectorRange()
{
    const QList<int> notes = currentNotes();
    if (notes.isEmpty()) {
        m_detector.setFrequencyRange(25.0, 2000.0);
        return;
    }
    const auto [lo, hi] = std::minmax_element(notes.cbegin(), notes.cend());
    m_detector.setFrequencyRange(Notes::frequency(*lo, m_a4) * 0.6, Notes::frequency(*hi, m_a4) * 2.2);
}

void TunerController::clearMeasurement()
{
    m_history.clear();
    m_candidate = -1;
    m_candidateFrames = 0;
    m_inTuneFrames = 0;
    m_activeString = m_autoDetect ? -1 : m_selected;
    if (m_hasSignal) {
        m_hasSignal = false;
    }
    m_cents = 0.0;
    if (!currentNotes().isEmpty()) {
        m_nearestMidi = currentNotes().value(m_selected);
    }
    Q_EMIT measurementChanged();
}

void TunerController::analyse()
{
    const quint64 written = m_engine->samplesWritten();
    if (written == m_lastWritten || !m_engine->latestSamples(m_window.data(), WindowSize)) {
        return;
    }
    m_lastWritten = written;

    const PitchDetector::Result r = m_detector.analyse(m_window.data());
    const double db = std::max(MinDb, 20.0 * std::log10(std::max(r.rms, 1e-9)));
    // Peak hold falls back at ~12 dB/s.
    const double peak = std::max(db, m_peakDb - 12.0 * AnalysisIntervalMs / 1000.0);
    if (std::abs(db - m_levelDb) > 0.05 || std::abs(peak - m_peakDb) > 0.05) {
        m_levelDb = db;
        m_peakDb = peak;
        Q_EMIT levelChanged();
    }

    const bool valid = r.frequency > 0.0 && db > m_noiseGate && r.clarity >= MinClarity;
    if (!valid) {
        if (m_hasSignal && (!m_sinceSignal.isValid() || m_sinceSignal.elapsed() > SignalHoldMs)) {
            m_hasSignal = false;
            m_history.clear();
            m_inTuneFrames = 0;
            Q_EMIT measurementChanged();
        }
        return;
    }
    m_sinceSignal.restart();

    // Median filter rejects single-frame octave jumps.
    m_history.push_back(r.frequency);
    if (m_history.size() > MedianLength) {
        m_history.erase(m_history.begin());
    }
    std::vector<double> sorted = m_history;
    std::nth_element(sorted.begin(), sorted.begin() + sorted.size() / 2, sorted.end());
    const double freq = sorted[sorted.size() / 2];
    const double midiF = Notes::midiFromFrequency(freq, m_a4);

    const QList<int> notes = currentNotes();
    int targetMidi;
    if (notes.isEmpty()) {
        targetMidi = int(std::lround(midiF));
        m_activeString = -1;
    } else if (m_autoDetect) {
        int nearest = 0;
        for (int i = 1; i < notes.size(); ++i) {
            if (std::abs(midiF - notes[i]) < std::abs(midiF - notes[nearest])) {
                nearest = i;
            }
        }
        if (m_activeString < 0 || !m_hasSignal) {
            m_activeString = nearest;
            m_candidateFrames = 0;
        } else if (nearest != m_activeString) {
            if (nearest == m_candidate) {
                ++m_candidateFrames;
            } else {
                m_candidate = nearest;
                m_candidateFrames = 1;
            }
            if (m_candidateFrames >= StringSwitchFrames) {
                m_activeString = nearest;
                m_candidateFrames = 0;
                m_inTuneFrames = 0;
            }
        } else {
            m_candidateFrames = 0;
        }
        if (m_selected != m_activeString) {
            m_selected = m_activeString;
            Q_EMIT selectedStringChanged();
            Q_EMIT referenceChanged();
        }
        targetMidi = notes[m_activeString];
    } else {
        m_activeString = m_selected;
        targetMidi = notes[m_selected];
    }

    const double cents = (midiF - targetMidi) * 100.0;
    // Light exponential smoothing; the QML needle adds its own spring on top.
    m_cents = (m_hasSignal && targetMidi == m_nearestMidi) ? m_cents * 0.5 + cents * 0.5 : cents;
    m_frequency = freq;
    m_nearestMidi = targetMidi;
    m_hasSignal = true;

    if (m_activeString >= 0 && std::abs(m_cents) <= m_inTuneThreshold) {
        if (++m_inTuneFrames == TunedAfterFrames && m_activeString < m_tuned.size() && !m_tuned[m_activeString]) {
            m_tuned[m_activeString] = true;
            Q_EMIT stringsChanged();
        }
    } else {
        m_inTuneFrames = 0;
    }

    Q_EMIT measurementChanged();
}

// ---------------------------------------------------------------------------
// Settings

void TunerController::setDisplayStyle(DisplayStyle style)
{
    if (m_displayStyle == style) {
        return;
    }
    m_displayStyle = style;
    generalGroup().writeEntry("DisplayStyle", int(style));
    Q_EMIT displayStyleChanged();
}

void TunerController::setA4(int hz)
{
    hz = std::clamp(hz, 400, 480);
    if (m_a4 == hz) {
        return;
    }
    m_a4 = hz;
    generalGroup().writeEntry("A4", hz);
    updateDetectorRange();
    Q_EMIT a4Changed();
    Q_EMIT stringsChanged();
    Q_EMIT referenceChanged();
    Q_EMIT measurementChanged();
    updateTone(false);
}

void TunerController::setInTuneThreshold(double cents)
{
    cents = std::clamp(cents, 0.5, 10.0);
    if (qFuzzyCompare(m_inTuneThreshold, cents)) {
        return;
    }
    m_inTuneThreshold = cents;
    generalGroup().writeEntry("InTuneThreshold", cents);
    Q_EMIT inTuneThresholdChanged();
}

void TunerController::setNoiseGate(int db)
{
    db = std::clamp(db, -90, -10);
    if (m_noiseGate == db) {
        return;
    }
    m_noiseGate = db;
    generalGroup().writeEntry("NoiseGate", db);
    Q_EMIT noiseGateChanged();
}

// ---------------------------------------------------------------------------
// Reference tone

int TunerController::referenceMidi() const
{
    const QList<int> notes = currentNotes();
    if (notes.isEmpty()) {
        return m_chromaticReference;
    }
    return notes.value(std::clamp(m_selected, 0, int(notes.size()) - 1));
}

QString TunerController::referenceLetter() const
{
    return Notes::letter(referenceMidi());
}

int TunerController::referenceOctave() const
{
    return Notes::octave(referenceMidi());
}

double TunerController::referenceFrequency() const
{
    return Notes::frequency(referenceMidi(), m_a4);
}

void TunerController::shiftReference(int semitones)
{
    m_chromaticReference = std::clamp(m_chromaticReference + semitones, 24, 96);
    Q_EMIT referenceChanged();
    updateTone(true);
}

void TunerController::updateTone(bool retrigger)
{
    ToneGenerator &gen = m_engine->generator();
    gen.setFrequency(referenceFrequency());
    if (m_playing && retrigger) {
        gen.trigger();
        m_referenceTimer.start(); // restart the cycle so each note gets its full time
    }
}

void TunerController::onReferenceTick()
{
    if (!m_playing) {
        return;
    }
    const int count = int(currentNotes().size());
    if (m_cycleStrings && count > 0) {
        m_selected = (m_selected + 1) % count;
        Q_EMIT selectedStringChanged();
        Q_EMIT referenceChanged();
        updateTone(true);
    } else if (m_timbre == Pluck) {
        m_engine->generator().trigger();
    }
}

bool TunerController::referenceAvailable() const
{
    return !m_autoDetect || isChromatic();
}

void TunerController::setPlaying(bool playing)
{
    if (m_playing == playing || (playing && !referenceAvailable())) {
        return;
    }
    m_playing = playing;
    if (playing) {
        updateTone(false);
        m_engine->generator().trigger();
        m_engine->setPlaybackEnabled(true);
        m_referenceTimer.start();
    } else {
        m_referenceTimer.stop();
        m_engine->setPlaybackEnabled(false);
    }
    Q_EMIT playingChanged();
}

void TunerController::setTimbre(Timbre timbre)
{
    if (m_timbre == timbre) {
        return;
    }
    m_timbre = timbre;
    m_engine->generator().setTimbre(ToneGenerator::Timbre(timbre));
    generalGroup().writeEntry("Timbre", int(timbre));
    updateTone(true);
    Q_EMIT timbreChanged();
}

void TunerController::setVolume(int volume)
{
    volume = std::clamp(volume, 0, 100);
    if (m_volume == volume) {
        return;
    }
    m_volume = volume;
    m_engine->generator().setVolume(volume / 100.0);
    generalGroup().writeEntry("Volume", volume);
    Q_EMIT volumeChanged();
}

void TunerController::setCycleStrings(bool cycle)
{
    if (m_cycleStrings == cycle) {
        return;
    }
    m_cycleStrings = cycle;
    generalGroup().writeEntry("CycleStrings", cycle);
    Q_EMIT cycleStringsChanged();
}

// ---------------------------------------------------------------------------
// Devices

bool TunerController::audioAvailable() const
{
    return m_engine->isConnected();
}

static QVariantList deviceList(const QList<AudioEngine::Device> &devices)
{
    QVariantList list;
    list.append(QVariantMap{{QStringLiteral("name"), QString()}, {QStringLiteral("description"), i18n("System default")}});
    for (const auto &d : devices) {
        list.append(QVariantMap{{QStringLiteral("name"), d.name}, {QStringLiteral("description"), d.description}});
    }
    return list;
}

QVariantList TunerController::inputDevices() const
{
    return deviceList(m_engine->inputDevices());
}

QVariantList TunerController::outputDevices() const
{
    return deviceList(m_engine->outputDevices());
}

void TunerController::setInputDevice(const QString &name)
{
    if (m_inputDevice == name) {
        return;
    }
    m_inputDevice = name;
    generalGroup().writeEntry("InputDevice", name);
    m_engine->setInputTarget(name);
    clearMeasurement();
    Q_EMIT inputDeviceChanged();
}

void TunerController::setOutputDevice(const QString &name)
{
    if (m_outputDevice == name) {
        return;
    }
    m_outputDevice = name;
    generalGroup().writeEntry("OutputDevice", name);
    m_engine->setOutputTarget(name);
    Q_EMIT outputDeviceChanged();
}

// ---------------------------------------------------------------------------
// Custom tunings

QVariantList TunerController::customTunings() const
{
    QVariantList list;
    for (int i = 0; i < m_instruments.size(); ++i) {
        const Instrument &inst = m_instruments[i];
        for (int t = 0; t < inst.tunings.size(); ++t) {
            if (!inst.tunings[t].custom) {
                continue;
            }
            const QString instrumentLabel = inst.variant.isEmpty() ? inst.name : i18nc("instrument, variant", "%1 (%2)", inst.name, inst.variant);
            list.append(QVariantMap{
                {QStringLiteral("instrumentIndex"), i},
                {QStringLiteral("tuningIndex"), t},
                {QStringLiteral("instrument"), instrumentLabel},
                {QStringLiteral("name"), inst.tunings[t].name},
                {QStringLiteral("notes"), formatNotes(inst.tunings[t].notes)},
            });
        }
    }
    return list;
}

QString TunerController::validateNotes(const QString &notes) const
{
    const auto parsed = Notes::parseList(notes);
    if (!parsed) {
        return i18n("Use note names with octave numbers, for example: E2 A2 D3 G3 B3 E4");
    }
    if (parsed->isEmpty()) {
        return i18n("Enter at least one note.");
    }
    if (parsed->size() > 12) {
        return i18n("A tuning can have at most 12 strings.");
    }
    return QString();
}

QString TunerController::addCustomTuning(int instrumentIndex, const QString &name, const QString &notes)
{
    if (instrumentIndex < 0 || instrumentIndex >= m_instruments.size()) {
        return i18n("Choose an instrument.");
    }
    const QString trimmed = name.trimmed();
    if (trimmed.isEmpty()) {
        return i18n("Enter a name for the tuning.");
    }
    if (trimmed.contains(QLatin1Char('|'))) {
        return i18n("The name cannot contain the “|” character.");
    }
    const QString error = validateNotes(notes);
    if (!error.isEmpty()) {
        return error;
    }
    Instrument &inst = m_instruments[instrumentIndex];
    for (const Tuning &t : std::as_const(inst.tunings)) {
        if (t.name == trimmed) {
            return i18n("%1 already has a tuning called “%2”.", inst.name, trimmed);
        }
    }
    inst.tunings.append(Tuning{trimmed, *Notes::parseList(notes), true});
    saveCustomTunings();
    Q_EMIT tuningsChanged();
    Q_EMIT instrumentsChanged();
    return QString();
}

void TunerController::removeCustomTuning(int instrumentIndex, int tuningIndex)
{
    if (instrumentIndex < 0 || instrumentIndex >= m_instruments.size()) {
        return;
    }
    Instrument &inst = m_instruments[instrumentIndex];
    if (tuningIndex < 0 || tuningIndex >= inst.tunings.size() || !inst.tunings[tuningIndex].custom) {
        return;
    }
    const bool affectsCurrent = instrumentIndex == m_instrument;
    const bool wasSelected = affectsCurrent && tuningIndex == m_tuning;
    inst.tunings.removeAt(tuningIndex);
    saveCustomTunings();

    if (affectsCurrent && (wasSelected || tuningIndex < m_tuning)) {
        const int newIndex = wasSelected ? 0 : m_tuning - 1;
        m_tuning = -1; // force setTuningIndex to apply
        setTuningIndex(newIndex);
    }
    Q_EMIT tuningsChanged();
}
