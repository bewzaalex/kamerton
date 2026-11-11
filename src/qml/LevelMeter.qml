// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

/// Horizontal input level meter in dB with a peak-hold tick and a noise gate marker.
Item {
    id: meter

    property real db: -70
    property real peak: -70
    property real gate: -55
    property real minimum: -70

    function fraction(value) {
        return Math.max(0, Math.min(1, (value - minimum) / -minimum));
    }

    implicitWidth: Kirigami.Units.gridUnit * 9
    implicitHeight: Kirigami.Units.gridUnit

    Accessible.role: Accessible.ProgressBar
    Accessible.name: i18nc("@label", "Input level")
    Accessible.description: i18nc("@info accessible", "%1 dB, noise gate at %2 dB", db.toFixed(0), gate)

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 8
        radius: height / 2
        color: Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.2)

        Rectangle {
            height: parent.height
            radius: parent.radius
            width: Math.max(height, parent.width * meter.fraction(meter.db))
            visible: meter.db > meter.minimum
            color: meter.db > -6 ? Kirigami.Theme.negativeTextColor
                 : meter.db > -18 ? Kirigami.Theme.neutralTextColor
                 : Kirigami.Theme.positiveTextColor
            Behavior on width {
                SmoothedAnimation {
                    velocity: 600
                }
            }
        }

        // Peak hold.
        Rectangle {
            visible: meter.peak > meter.minimum
            x: Math.min(parent.width - width, parent.width * meter.fraction(meter.peak))
            width: 2
            height: parent.height
            color: Kirigami.Theme.textColor
            opacity: 0.7
        }
    }

    // Noise gate marker.
    Rectangle {
        id: gateMarker
        x: track.width * meter.fraction(meter.gate) - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: 2
        height: 14
        radius: 1
        color: Kirigami.Theme.neutralTextColor

        HoverHandler {
            id: gateHover
            margin: 4
        }
        QQC2.ToolTip.text: i18nc("@info:tooltip", "Noise gate: %1 dB", meter.gate)
        QQC2.ToolTip.visible: gateHover.hovered
        QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
    }
}
