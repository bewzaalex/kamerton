// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

/// Strobe tuner: stripes drift left when flat, right when sharp and stand still when in tune.
Item {
    id: strobe

    property real cents: 0
    property bool active: false
    property color toneColor: Kirigami.Theme.textColor

    // Pixels travelled by the 1× band; speed is proportional to the error in cents.
    property real phase: 0

    implicitWidth: 400
    implicitHeight: bands.implicitHeight

    Accessible.role: Accessible.Indicator
    Accessible.name: active ? i18nc("@info accessible", "%1 cents", cents.toFixed(1)) : i18nc("@info accessible", "No signal")

    FrameAnimation {
        running: strobe.visible && strobe.active
        onTriggered: strobe.phase += Math.max(-50, Math.min(50, strobe.cents)) * frameTime * 8
    }

    ColumnLayout {
        id: bands
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(parent.width, Kirigami.Units.gridUnit * 36)
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Kirigami.Units.smallSpacing

        Repeater {
            model: [
                { period: 24, speed: 1.0, opacity: 1.0 },
                { period: 48, speed: 2.0, opacity: 0.8 },
                { period: 12, speed: 0.5, opacity: 0.6 }
            ]
            delegate: Rectangle {
                id: band
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 2
                radius: Kirigami.Units.cornerRadius
                color: Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.06)
                clip: true

                Row {
                    readonly property real period: band.modelData.period
                    x: ((strobe.phase * band.modelData.speed) % period + period) % period - period
                    height: parent.height
                    Repeater {
                        model: Math.ceil(band.width / band.modelData.period) + 2
                        delegate: Item {
                            width: band.modelData.period
                            height: band.height
                            Rectangle {
                                width: parent.width / 2
                                height: parent.height
                                color: strobe.active ? strobe.toneColor : Kirigami.Theme.disabledTextColor
                                opacity: strobe.active ? band.modelData.opacity : 0.25
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            QQC2.Label {
                text: i18nc("strobe hint", "◀ drifting left: flat")
                font: Kirigami.Theme.smallFont
                color: Kirigami.Theme.disabledTextColor
            }
            Item {
                Layout.fillWidth: true
            }
            QQC2.Label {
                text: i18nc("strobe hint", "standing still: in tune")
                font: Kirigami.Theme.smallFont
                color: Kirigami.Theme.disabledTextColor
            }
            Item {
                Layout.fillWidth: true
            }
            QQC2.Label {
                text: i18nc("strobe hint", "sharp: drifting right ▶")
                font: Kirigami.Theme.smallFont
                color: Kirigami.Theme.disabledTextColor
            }
        }
    }

    // Center reference line.
    Rectangle {
        width: 2
        x: (parent.width - width) / 2
        y: bands.y - Kirigami.Units.smallSpacing
        height: bands.height - Kirigami.Units.gridUnit
        color: Kirigami.Theme.textColor
        opacity: 0.6
    }
}
