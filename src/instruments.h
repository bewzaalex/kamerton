// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include <QList>
#include <QString>
#include <QStringList>

#include <optional>

struct Tuning {
    QString name;
    QList<int> notes; ///< MIDI note numbers, lowest string first
    bool custom = false;
};

struct Instrument {
    QString id;
    QString name;
    QString variant;
    QString group;
    int headLeft = 0; ///< tuning pegs on the left side of the headstock, 0 = no headstock art
    int headRight = 0;
    QList<Tuning> tunings;

    bool isChromatic() const
    {
        return tunings.isEmpty() || tunings.constFirst().notes.isEmpty();
    }
};

namespace Notes
{
/// Parses "E2", "F#3", "Bb1"… into a MIDI note number.
std::optional<int> parse(const QString &text);
/// Parses a whitespace separated list of notes; returns nullopt if any token is invalid.
std::optional<QList<int>> parseList(const QString &text);

QString letter(int midi); ///< "C", "F♯"…
int octave(int midi);
QString name(int midi); ///< letter + octave, e.g. "F♯3"
QString asciiName(int midi); ///< "F#3", used for storage
double frequency(int midi, double a4);
/// Fractional MIDI number of a frequency.
double midiFromFrequency(double hz, double a4);
}

namespace Instruments
{
QList<Instrument> builtin();
}
