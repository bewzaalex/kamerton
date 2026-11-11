// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Shapes
import org.kde.kirigami as Kirigami

/// Analog meter: ±50 cents over a 120° arc, the needle moves on a spring.
Item {
    id: gauge

    property real cents: 0
    property bool active: false
    property color toneColor: Kirigami.Theme.textColor
    property real inTuneZone: 3

    readonly property real degPerCent: 1.2
    readonly property color trackColor: Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.25)

    property real needleAngle: active ? Math.max(-50, Math.min(50, cents)) * degPerCent : 0
    Behavior on needleAngle {
        SpringAnimation {
            spring: 4
            damping: 0.35
            epsilon: 0.05
        }
    }

    implicitWidth: 400
    implicitHeight: 230

    Accessible.role: Accessible.Indicator
    Accessible.name: active ? i18nc("@info accessible", "%1 cents", cents.toFixed(1)) : i18nc("@info accessible", "No signal")

    // Fixed 400×230 drawing, scaled to the available space.
    Item {
        id: dial
        width: 400
        height: 230
        anchors.centerIn: parent
        scale: Math.min(gauge.width / width, gauge.height / height)

        component Arc: ShapePath {
            property real from: 0
            property real to: 0
            property real radius: 170
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            PathAngleArc {
                centerX: 200
                centerY: 210
                radiusX: radius
                radiusY: radius
                startAngle: -90 + from * gauge.degPerCent
                sweepAngle: (to - from) * gauge.degPerCent
            }
        }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            Arc {
                from: -50
                to: 50
                strokeColor: gauge.trackColor
                strokeWidth: 2
            }
            Arc {
                from: -15
                to: -gauge.inTuneZone
                radius: 178
                strokeWidth: 10
                strokeColor: Qt.alpha(Kirigami.Theme.neutralTextColor, 0.45)
            }
            Arc {
                from: gauge.inTuneZone
                to: 15
                radius: 178
                strokeWidth: 10
                strokeColor: Qt.alpha(Kirigami.Theme.neutralTextColor, 0.45)
            }
            Arc {
                from: -gauge.inTuneZone
                to: gauge.inTuneZone
                radius: 178
                strokeWidth: 10
                strokeColor: Kirigami.Theme.positiveTextColor
            }
        }

        Repeater {
            model: 21
            delegate: Rectangle {
                required property int index
                readonly property int value: index * 5 - 50
                readonly property bool major: value % 25 === 0
                width: major ? 2 : 1.5
                height: major ? 20 : 10
                x: 200 - width / 2
                y: 210 - 166
                color: major ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
                antialiasing: true
                transform: Rotation {
                    origin.x: width / 2
                    origin.y: 166
                    angle: value * gauge.degPerCent
                }
            }
        }

        Repeater {
            model: [-50, -25, 0, 25, 50]
            delegate: QQC2.Label {
                required property int modelData
                readonly property real rad: modelData * gauge.degPerCent * Math.PI / 180
                text: modelData > 0 ? "+" + modelData : modelData < 0 ? "−" + (-modelData) : "0"
                color: Kirigami.Theme.disabledTextColor
                font.pixelSize: 12
                x: 200 + 128 * Math.sin(rad) - width / 2
                y: 210 - 128 * Math.cos(rad) - height / 2
            }
        }

        QQC2.Label {
            text: "♭"
            font.pixelSize: 24
            color: Kirigami.Theme.disabledTextColor
            x: 40 - width / 2
            y: 196 - height / 2
        }
        QQC2.Label {
            text: "♯"
            font.pixelSize: 24
            color: Kirigami.Theme.disabledTextColor
            x: 360 - width / 2
            y: 196 - height / 2
        }

        Rectangle {
            id: needle
            width: 4
            height: 160
            radius: 2
            x: 200 - width / 2
            y: 210 - height
            color: gauge.active ? gauge.toneColor : Kirigami.Theme.disabledTextColor
            antialiasing: true
            transform: Rotation {
                origin.x: needle.width / 2
                origin.y: needle.height
                angle: gauge.needleAngle
            }
            Behavior on color {
                ColorAnimation {
                    duration: Kirigami.Units.shortDuration
                }
            }
        }

        Rectangle {
            width: 20
            height: 20
            radius: 10
            x: 190
            y: 200
            color: needle.color
            Rectangle {
                anchors.centerIn: parent
                width: 8
                height: 8
                radius: 4
                color: Kirigami.Theme.backgroundColor
            }
        }
    }
}
