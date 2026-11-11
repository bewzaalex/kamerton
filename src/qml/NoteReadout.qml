// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import io.github.bewzaalex.kamerton

/// Big note name with detected frequency, cents and a plain-language hint.
RowLayout {
    id: root

    property color toneColor: Kirigami.Theme.textColor

    readonly property bool active: TunerController.hasSignal
    readonly property real cents: TunerController.cents

    spacing: Kirigami.Units.gridUnit

    Row {
        Layout.alignment: Qt.AlignBottom
        QQC2.Label {
            id: noteLabel
            text: TunerController.noteLetter
            font.pixelSize: Kirigami.Units.gridUnit * 5
            font.weight: Font.Light
            color: root.toneColor
            Behavior on color {
                ColorAnimation {
                    duration: Kirigami.Units.shortDuration
                }
            }
        }
        QQC2.Label {
            text: TunerController.noteOctave
            font.pixelSize: Kirigami.Units.gridUnit * 1.6
            color: Kirigami.Theme.disabledTextColor
            anchors.baseline: noteLabel.baseline
        }
    }

    ColumnLayout {
        Layout.alignment: Qt.AlignBottom
        Layout.bottomMargin: Kirigami.Units.largeSpacing
        Layout.minimumWidth: Kirigami.Units.gridUnit * 12
        spacing: Kirigami.Units.smallSpacing

        QQC2.Label {
            text: root.active ? i18nc("frequency", "%1 Hz", TunerController.frequency.toFixed(2)) : i18nc("@info", "Play a string…")
            font.pixelSize: Kirigami.Units.gridUnit * 1.4
            font.features: { "tnum": 1 }
            color: root.active ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
        }

        QQC2.Label {
            text: TunerController.activeString >= 0 && !TunerController.chromatic
                ? i18nc("target frequency, string number", "target %1 Hz · string %2",
                        TunerController.targetFrequency.toFixed(2), TunerController.strings[TunerController.activeString]?.number ?? "")
                : i18nc("target frequency", "target %1 Hz", TunerController.targetFrequency.toFixed(2))
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
        }

        RowLayout {
            visible: root.active
            spacing: Kirigami.Units.smallSpacing

            Rectangle {
                implicitWidth: centsLabel.implicitWidth + Kirigami.Units.largeSpacing * 2
                implicitHeight: centsLabel.implicitHeight + Kirigami.Units.smallSpacing
                radius: height / 2
                color: "transparent"
                border.width: 1.5
                border.color: root.toneColor
                QQC2.Label {
                    id: centsLabel
                    anchors.centerIn: parent
                    text: {
                        const c = root.cents;
                        const sign = c > 0.05 ? "+" : c < -0.05 ? "−" : "±";
                        return i18nc("cents offset", "%1%2 ¢", sign, Math.abs(c).toFixed(1));
                    }
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                    color: root.toneColor
                }
            }

            QQC2.Label {
                text: TunerController.inTune ? i18nc("@info tuning status", "In tune")
                    : root.cents < 0 ? i18nc("@info tuning status", "Too low · tighten")
                    : i18nc("@info tuning status", "Too high · loosen")
                font.weight: Font.Medium
            }
        }
    }
}
