// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include <QElapsedTimer>
#include <QObject>
#include <QQmlEngine>
#include <QTimer>
#include <QVariantList>

#include <KSharedConfig>

#include <memory>
#include <vector>

#include "instruments.h"
#include "pitchdetector.h"

class AudioEngine;

/**
 * Everything the QML UI talks to: instrument/tuning selection,
 * live pitch measurement, reference tone playback and settings.
 */
class TunerController : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    // Instrument and tuning
    Q_PROPERTY(QVariantList instruments READ instruments NOTIFY instrumentsChanged)
    Q_PROPERTY(int instrumentIndex READ instrumentIndex WRITE setInstrumentIndex NOTIFY instrumentChanged)
    Q_PROPERTY(QString instrumentName READ instrumentName NOTIFY instrumentChanged)
    Q_PROPERTY(QString instrumentVariant READ instrumentVariant NOTIFY instrumentChanged)
    Q_PROPERTY(int headLeft READ headLeft NOTIFY instrumentChanged)
    Q_PROPERTY(int headRight READ headRight NOTIFY instrumentChanged)
    Q_PROPERTY(bool chromatic READ isChromatic NOTIFY instrumentChanged)
    Q_PROPERTY(QVariantList tunings READ tunings NOTIFY tuningsChanged)
    Q_PROPERTY(int tuningIndex READ tuningIndex WRITE setTuningIndex NOTIFY tuningChanged)
    Q_PROPERTY(QString tuningName READ tuningName NOTIFY tuningChanged)
    Q_PROPERTY(QString tuningNotes READ tuningNotes NOTIFY tuningChanged)
    Q_PROPERTY(QVariantList strings READ strings NOTIFY stringsChanged)
    Q_PROPERTY(int selectedString READ selectedString WRITE setSelectedString NOTIFY selectedStringChanged)
    Q_PROPERTY(bool autoDetect READ autoDetect WRITE setAutoDetect NOTIFY autoDetectChanged)
    Q_PROPERTY(int tunedCount READ tunedCount NOTIFY stringsChanged)

    // Live measurement
    Q_PROPERTY(bool hasSignal READ hasSignal NOTIFY measurementChanged)
    Q_PROPERTY(double frequency READ frequency NOTIFY measurementChanged)
    Q_PROPERTY(double cents READ cents NOTIFY measurementChanged)
    Q_PROPERTY(QString noteLetter READ noteLetter NOTIFY measurementChanged)
    Q_PROPERTY(int noteOctave READ noteOctave NOTIFY measurementChanged)
    Q_PROPERTY(double targetFrequency READ targetFrequency NOTIFY measurementChanged)
    Q_PROPERTY(int activeString READ activeString NOTIFY measurementChanged)
    Q_PROPERTY(bool inTune READ inTune NOTIFY measurementChanged)
    Q_PROPERTY(double levelDb READ levelDb NOTIFY levelChanged)
    Q_PROPERTY(double peakDb READ peakDb NOTIFY levelChanged)

    // Settings
    Q_PROPERTY(DisplayStyle displayStyle READ displayStyle WRITE setDisplayStyle NOTIFY displayStyleChanged)
    Q_PROPERTY(int a4 READ a4 WRITE setA4 NOTIFY a4Changed)
    Q_PROPERTY(double inTuneThreshold READ inTuneThreshold WRITE setInTuneThreshold NOTIFY inTuneThresholdChanged)
    Q_PROPERTY(int noiseGate READ noiseGate WRITE setNoiseGate NOTIFY noiseGateChanged)
    Q_PROPERTY(int minNoiseGate READ minNoiseGate CONSTANT)
    Q_PROPERTY(int maxNoiseGate READ maxNoiseGate CONSTANT)
    Q_PROPERTY(int defaultNoiseGate READ defaultNoiseGate CONSTANT)
    Q_PROPERTY(int noiseMeasureMs READ noiseMeasureMs CONSTANT)
    Q_PROPERTY(bool measuringNoise READ measuringNoise NOTIFY measuringNoiseChanged)

    // Reference tone, only available while autoDetect is off (or for the chromatic tuner)
    Q_PROPERTY(bool referenceAvailable READ referenceAvailable NOTIFY referenceAvailableChanged)
    Q_PROPERTY(bool playing READ playing WRITE setPlaying NOTIFY playingChanged)
    Q_PROPERTY(Timbre timbre READ timbre WRITE setTimbre NOTIFY timbreChanged)
    Q_PROPERTY(int volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(bool cycleStrings READ cycleStrings WRITE setCycleStrings NOTIFY cycleStringsChanged)
    Q_PROPERTY(QString referenceLetter READ referenceLetter NOTIFY referenceChanged)
    Q_PROPERTY(int referenceOctave READ referenceOctave NOTIFY referenceChanged)
    Q_PROPERTY(double referenceFrequency READ referenceFrequency NOTIFY referenceChanged)

    // Audio devices
    Q_PROPERTY(bool audioAvailable READ audioAvailable CONSTANT)
    Q_PROPERTY(QString audioError READ audioError NOTIFY audioErrorChanged)
    Q_PROPERTY(QVariantList inputDevices READ inputDevices NOTIFY devicesChanged)
    Q_PROPERTY(QVariantList outputDevices READ outputDevices NOTIFY devicesChanged)
    Q_PROPERTY(QString inputDevice READ inputDevice WRITE setInputDevice NOTIFY inputDeviceChanged)
    Q_PROPERTY(QString outputDevice READ outputDevice WRITE setOutputDevice NOTIFY outputDeviceChanged)

    // Custom tunings
    Q_PROPERTY(QVariantList customTunings READ customTunings NOTIFY tuningsChanged)

public:
    static constexpr double MinDb = -70.0;
    // The gate stays inside the level meter's range, so its marker can always be dragged.
    static constexpr int MinNoiseGate = -70;
    static constexpr int MaxNoiseGate = -10;
    static constexpr int DefaultNoiseGate = -55;
    /// "Set from room noise" listens this long and puts the gate this far above the loudest noise.
    static constexpr int NoiseMeasureMs = 2000;
    static constexpr int NoiseGateMargin = 6;

    enum DisplayStyle {
        Needle,
        Strobe,
        Bar,
    };
    Q_ENUM(DisplayStyle)

    enum Timbre {
        Pluck,
        Sine,
        Organ,
    };
    Q_ENUM(Timbre)

    explicit TunerController(QObject *parent = nullptr);
    ~TunerController() override;

    QVariantList instruments() const;
    int instrumentIndex() const
    {
        return m_instrument;
    }
    void setInstrumentIndex(int index);
    QString instrumentName() const;
    QString instrumentVariant() const;
    int headLeft() const;
    int headRight() const;
    bool isChromatic() const;

    QVariantList tunings() const;
    int tuningIndex() const
    {
        return m_tuning;
    }
    void setTuningIndex(int index);
    QString tuningName() const;
    QString tuningNotes() const;

    QVariantList strings() const;
    int selectedString() const
    {
        return m_selected;
    }
    void setSelectedString(int index);
    bool autoDetect() const
    {
        return m_autoDetect;
    }
    void setAutoDetect(bool enabled);
    int tunedCount() const;

    bool hasSignal() const
    {
        return m_hasSignal;
    }
    double frequency() const
    {
        return m_frequency;
    }
    double cents() const
    {
        return m_cents;
    }
    QString noteLetter() const;
    int noteOctave() const;
    double targetFrequency() const;
    int activeString() const
    {
        return m_activeString;
    }
    bool inTune() const;
    double levelDb() const
    {
        return m_levelDb;
    }
    double peakDb() const
    {
        return m_peakDb;
    }

    DisplayStyle displayStyle() const
    {
        return m_displayStyle;
    }
    void setDisplayStyle(DisplayStyle style);
    int a4() const
    {
        return m_a4;
    }
    void setA4(int hz);
    double inTuneThreshold() const
    {
        return m_inTuneThreshold;
    }
    void setInTuneThreshold(double cents);
    int noiseGate() const
    {
        return m_noiseGate;
    }
    void setNoiseGate(int db);
    static int minNoiseGate()
    {
        return MinNoiseGate;
    }
    static int maxNoiseGate()
    {
        return MaxNoiseGate;
    }
    static int defaultNoiseGate()
    {
        return DefaultNoiseGate;
    }
    static int noiseMeasureMs()
    {
        return NoiseMeasureMs;
    }
    bool measuringNoise() const
    {
        return m_noiseMeasure.isActive();
    }

    bool referenceAvailable() const;
    bool playing() const
    {
        return m_playing;
    }
    void setPlaying(bool playing);
    Timbre timbre() const
    {
        return m_timbre;
    }
    void setTimbre(Timbre timbre);
    int volume() const
    {
        return m_volume;
    }
    void setVolume(int volume);
    bool cycleStrings() const
    {
        return m_cycleStrings;
    }
    void setCycleStrings(bool cycle);
    QString referenceLetter() const;
    int referenceOctave() const;
    double referenceFrequency() const;

    bool audioAvailable() const;
    QString audioError() const
    {
        return m_audioError;
    }
    QVariantList inputDevices() const;
    QVariantList outputDevices() const;
    QString inputDevice() const
    {
        return m_inputDevice;
    }
    void setInputDevice(const QString &name);
    QString outputDevice() const
    {
        return m_outputDevice;
    }
    void setOutputDevice(const QString &name);

    QVariantList customTunings() const;

    Q_INVOKABLE void resetTuned();
    /// Listens to the room for a moment and sets the noise gate just above its noise.
    Q_INVOKABLE void measureNoiseGate();
    /// Moves the chromatic reference note by @p semitones.
    Q_INVOKABLE void shiftReference(int semitones);
    /// Returns an empty string when @p notes is valid, otherwise an error message.
    Q_INVOKABLE QString validateNotes(const QString &notes) const;
    /// Returns an empty string on success, otherwise an error message.
    Q_INVOKABLE QString addCustomTuning(int instrumentIndex, const QString &name, const QString &notes);
    Q_INVOKABLE void removeCustomTuning(int instrumentIndex, int tuningIndex);

Q_SIGNALS:
    void instrumentsChanged();
    void instrumentChanged();
    void tuningsChanged();
    void tuningChanged();
    void stringsChanged();
    void selectedStringChanged();
    void autoDetectChanged();
    void measurementChanged();
    void levelChanged();
    void displayStyleChanged();
    void a4Changed();
    void inTuneThresholdChanged();
    void noiseGateChanged();
    void measuringNoiseChanged();
    void noiseGateMeasured();
    void referenceAvailableChanged();
    void playingChanged();
    void timbreChanged();
    void volumeChanged();
    void cycleStringsChanged();
    void referenceChanged();
    void audioErrorChanged();
    void devicesChanged();
    void inputDeviceChanged();
    void outputDeviceChanged();

private:
    static constexpr int WindowSize = 8192; // ~170 ms at 48 kHz, enough periods for a low B (31 Hz)

    const Instrument &currentInstrument() const;
    const Tuning &currentTuning() const;
    QList<int> currentNotes() const;
    int referenceMidi() const;

    void loadSettings();
    void loadCustomTunings();
    void saveCustomTunings();
    KConfigGroup generalGroup() const;

    void updateDetectorRange();
    void updateTone(bool retrigger);
    void onReferenceTick();
    void analyse();
    void clearMeasurement();

    std::unique_ptr<AudioEngine> m_engine;
    PitchDetector m_detector;
    std::vector<float> m_window;
    QTimer m_analysisTimer;
    QTimer m_referenceTimer;
    QTimer m_noiseMeasure;
    double m_noiseMax = MinDb;
    QElapsedTimer m_sinceSignal;
    quint64 m_lastWritten = 0;

    KSharedConfigPtr m_config;

    QList<Instrument> m_instruments;
    int m_instrument = 0;
    int m_tuning = 0;
    int m_selected = 0;
    bool m_autoDetect = true;
    QList<bool> m_tuned;

    bool m_hasSignal = false;
    double m_frequency = 0.0;
    double m_cents = 0.0;
    int m_nearestMidi = 69;
    int m_activeString = -1;
    int m_candidate = -1;
    int m_candidateFrames = 0;
    int m_inTuneFrames = 0;
    double m_levelDb = MinDb;
    double m_peakDb = MinDb;
    std::vector<double> m_history;

    DisplayStyle m_displayStyle = Needle;
    int m_a4 = 440;
    double m_inTuneThreshold = 3.0;
    int m_noiseGate = DefaultNoiseGate;

    bool m_playing = false;
    Timbre m_timbre = Pluck;
    int m_volume = 60;
    bool m_cycleStrings = false;
    int m_chromaticReference = 69;

    QString m_audioError;
    QString m_inputDevice;
    QString m_outputDevice;
};
