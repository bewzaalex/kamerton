// SPDX-License-Identifier: GPL-3.0-or-later

#include "instruments.h"

#include <KLocalizedString>

#include <QRegularExpression>

#include <cmath>

namespace
{
const char *const SharpNames[12] = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"};

Tuning tuning(const QString &name, const char *notes)
{
    return Tuning{name, Notes::parseList(QString::fromLatin1(notes)).value_or(QList<int>{}), false};
}
}

std::optional<int> Notes::parse(const QString &text)
{
    static const QRegularExpression re(QStringLiteral("^([A-Ga-g])([#♯b♭]?)(-?\\d)$"));
    const auto m = re.match(text.trimmed());
    if (!m.hasMatch()) {
        return std::nullopt;
    }
    static const int base[7] = {9, 11, 0, 2, 4, 5, 7}; // A B C D E F G
    int pc = base[m.captured(1).toUpper().at(0).unicode() - u'A'];
    const QString acc = m.captured(2);
    if (acc == QLatin1String("#") || acc == QStringLiteral("♯")) {
        ++pc;
    } else if (acc == QLatin1String("b") || acc == QStringLiteral("♭")) {
        --pc;
    }
    const int midi = 12 * (m.captured(3).toInt() + 1) + pc;
    if (midi < 0 || midi > 127) {
        return std::nullopt;
    }
    return midi;
}

std::optional<QList<int>> Notes::parseList(const QString &text)
{
    QList<int> result;
    const QStringList tokens = text.split(QRegularExpression(QStringLiteral("[\\s,]+")), Qt::SkipEmptyParts);
    for (const QString &t : tokens) {
        const auto n = parse(t);
        if (!n) {
            return std::nullopt;
        }
        result.append(*n);
    }
    return result;
}

QString Notes::letter(int midi)
{
    QString s = QString::fromLatin1(SharpNames[((midi % 12) + 12) % 12]);
    s.replace(QLatin1Char('#'), QStringLiteral("♯"));
    return s;
}

int Notes::octave(int midi)
{
    return int(std::floor(midi / 12.0)) - 1;
}

QString Notes::name(int midi)
{
    return letter(midi) + QString::number(octave(midi));
}

QString Notes::asciiName(int midi)
{
    return QString::fromLatin1(SharpNames[((midi % 12) + 12) % 12]) + QString::number(octave(midi));
}

double Notes::frequency(int midi, double a4)
{
    return a4 * std::pow(2.0, (midi - 69) / 12.0);
}

double Notes::midiFromFrequency(double hz, double a4)
{
    return 69.0 + 12.0 * std::log2(hz / a4);
}

QList<Instrument> Instruments::builtin()
{
    const QString guitar = i18nc("@title instrument group", "Guitar");
    const QString bass = i18nc("@title instrument group", "Bass");
    const QString folk = i18nc("@title instrument group", "Folk");
    const QString violins = i18nc("@title instrument group", "Violin family");
    const QString other = i18nc("@title instrument group", "Other");
    const QString standard = i18nc("tuning name", "Standard");

    return {
        {QStringLiteral("guitar6"),
         i18n("Guitar"),
         i18n("6-string"),
         guitar,
         3,
         3,
         {tuning(standard, "E2 A2 D3 G3 B3 E4"),
          tuning(i18nc("tuning name", "Drop D"), "D2 A2 D3 G3 B3 E4"),
          tuning(i18nc("tuning name", "Half-step down"), "D#2 G#2 C#3 F#3 A#3 D#4"),
          tuning(i18nc("tuning name", "Full-step down"), "D2 G2 C3 F3 A3 D4"),
          tuning(i18nc("tuning name", "Drop C"), "C2 G2 C3 F3 A3 D4"),
          tuning(i18nc("tuning name", "DADGAD"), "D2 A2 D3 G3 A3 D4"),
          tuning(i18nc("tuning name", "Open G"), "D2 G2 D3 G3 B3 D4"),
          tuning(i18nc("tuning name", "Open D"), "D2 A2 D3 F#3 A3 D4"),
          tuning(i18nc("tuning name", "Open E"), "E2 B2 E3 G#3 B3 E4")}},
        {QStringLiteral("guitar7"),
         i18n("Guitar"),
         i18n("7-string"),
         guitar,
         4,
         3,
         {tuning(standard, "B1 E2 A2 D3 G3 B3 E4"), tuning(i18nc("tuning name", "Drop A"), "A1 E2 A2 D3 G3 B3 E4")}},
        {QStringLiteral("bass4"),
         i18n("Bass"),
         i18n("4-string"),
         bass,
         2,
         2,
         {tuning(standard, "E1 A1 D2 G2"), tuning(i18nc("tuning name", "Drop D"), "D1 A1 D2 G2"), tuning(i18nc("tuning name", "Half-step down"), "D#1 G#1 C#2 F#2")}},
        {QStringLiteral("bass5"),
         i18n("Bass"),
         i18n("5-string"),
         bass,
         3,
         2,
         {tuning(standard, "B0 E1 A1 D2 G2"), tuning(i18nc("tuning name", "High C"), "E1 A1 D2 G2 C3")}},
        {QStringLiteral("ukulele"),
         i18n("Ukulele"),
         i18n("soprano / concert / tenor"),
         folk,
         2,
         2,
         {tuning(i18nc("tuning name", "Standard (high G)"), "G4 C4 E4 A4"),
          tuning(i18nc("tuning name", "Low G"), "G3 C4 E4 A4"),
          tuning(i18nc("tuning name", "D tuning"), "A4 D4 F#4 B4"),
          tuning(i18nc("tuning name", "Baritone"), "D3 G3 B3 E4")}},
        {QStringLiteral("mandolin"), i18n("Mandolin"), i18n("4 courses"), folk, 0, 0, {tuning(standard, "G3 D4 A4 E5")}},
        {QStringLiteral("banjo5"),
         i18n("Banjo"),
         i18n("5-string"),
         folk,
         0,
         0,
         {tuning(i18nc("tuning name", "Open G"), "G4 D3 G3 B3 D4"),
          tuning(i18nc("tuning name", "Double C"), "G4 C3 G3 C4 D4"),
          tuning(i18nc("tuning name", "Open D"), "F#4 D3 F#3 A3 D4")}},
        {QStringLiteral("violin"), i18n("Violin"), QString(), violins, 0, 0, {tuning(standard, "G3 D4 A4 E5")}},
        {QStringLiteral("viola"), i18n("Viola"), QString(), violins, 0, 0, {tuning(standard, "C3 G3 D4 A4")}},
        {QStringLiteral("cello"), i18n("Cello"), QString(), violins, 0, 0, {tuning(standard, "C2 G2 D3 A3")}},
        {QStringLiteral("doublebass"),
         i18n("Double bass"),
         QString(),
         violins,
         0,
         0,
         {tuning(i18nc("tuning name", "Orchestral"), "E1 A1 D2 G2"), tuning(i18nc("tuning name", "Solo"), "F#1 B1 E2 A2")}},
        {QStringLiteral("chromatic"), i18n("Chromatic"), i18n("any note"), other, 0, 0, {Tuning{i18nc("tuning name", "All notes"), {}, false}}},
    };
}
