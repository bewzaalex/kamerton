// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

/// Input level meter in dB whose orange marker is the noise gate: drag it, click the meter,
/// use the arrow keys or the mouse wheel to move it, double-click to reset.
QQC2.Slider {
    id: root

    property real db: -70
    property real peak: -70
    property int gate: -55
    property int minimumGate: -70
    property int maximumGate: -10
    property int defaultGate: -55

    signal gateMoved(int gate)

    function fraction(value) {
        return Math.max(0, Math.min(1, (value - from) / (to - from)));
    }
    function dbText(value) {
        return i18nc("decibels", "%1 dB", String(Math.round(value)).replace("-", "−"));
    }
    function moveGate(value) {
        const v = Math.max(minimumGate, Math.min(maximumGate, Math.round(value)));
        // Dragging past the maximum must not leave the handle there.
        root.value = v;
        if (v !== gate) {
            gateMoved(v);
        }
    }

    readonly property real trackY: Kirigami.Units.gridUnit * 1.3
    readonly property real trackHeight: 12
    readonly property color gateColor: Kirigami.Theme.neutralTextColor
    readonly property color trackColor: Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.2)

    from: -70
    to: 0
    stepSize: 1
    value: gate
    wheelEnabled: true
    live: true
    hoverEnabled: true
    leftPadding: Kirigami.Units.largeSpacing
    rightPadding: Kirigami.Units.largeSpacing
    implicitWidth: Kirigami.Units.gridUnit * 20
    implicitHeight: trackY + trackHeight + Kirigami.Units.gridUnit * 1.3

    onMoved: moveGate(value)
    onGateChanged: value = gate

    Accessible.name: i18nc("@label:slider", "Noise gate")
    Accessible.description: i18nc("@info accessible", "Input level %1. Sounds below the noise gate are ignored.", dbText(db))

    QQC2.ToolTip.text: i18nc("@info:tooltip", "Drag to set the noise gate: sounds left of the marker are ignored. Double-click to reset.")
    QQC2.ToolTip.visible: hovered && !pressed
    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay * 3

    Keys.onPressed: event => {
        const steps = { [Qt.Key_PageUp]: 5, [Qt.Key_PageDown]: -5 };
        if (event.key in steps) {
            moveGate(gate + steps[event.key]);
        } else if (event.key === Qt.Key_Home) {
            moveGate(minimumGate);
        } else if (event.key === Qt.Key_End) {
            moveGate(maximumGate);
        } else {
            return;
        }
        event.accepted = true;
    }

    TapHandler {
        onDoubleTapped: root.moveGate(root.defaultGate)
    }

    background: Item {
        x: root.leftPadding
        width: root.availableWidth
        height: root.height

        // Level track: fill, the ignored zone below the gate, peak hold.
        Rectangle {
            id: track
            y: root.trackY
            width: parent.width
            height: root.trackHeight
            radius: height / 2
            color: root.trackColor
            clip: true

            Rectangle {
                height: parent.height
                radius: parent.radius
                width: Math.max(height, parent.width * root.fraction(root.db))
                visible: root.db > root.from
                color: root.db <= root.gate ? Kirigami.Theme.disabledTextColor
                     : root.db > -6 ? Kirigami.Theme.negativeTextColor
                     : root.db > -18 ? Kirigami.Theme.neutralTextColor
                     : Kirigami.Theme.positiveTextColor
                Behavior on width {
                    SmoothedAnimation {
                        velocity: 900
                    }
                }
            }

            // Hatching marks the sounds the gate ignores.
            Item {
                width: parent.width * root.fraction(root.gate)
                height: parent.height
                clip: true
                Repeater {
                    model: Math.ceil(track.width / 6) + 2
                    delegate: Rectangle {
                        required property int index
                        x: index * 6 - 6
                        y: -4
                        width: 2
                        height: track.height + 8
                        rotation: 45
                        color: Qt.alpha(root.gateColor, 0.45)
                    }
                }
            }

            Rectangle {
                visible: root.peak > root.from
                x: Math.min(parent.width - width, parent.width * root.fraction(root.peak))
                width: 2
                height: parent.height
                color: Kirigami.Theme.textColor
                opacity: 0.7
            }
        }

        // Scale.
        Repeater {
            model: [-70, -60, -50, -40, -30, -20, -10, 0]
            delegate: Item {
                required property int modelData
                x: track.width * root.fraction(modelData)
                y: track.y + track.height + 4
                Rectangle {
                    width: 1
                    height: 4
                    color: Kirigami.Theme.disabledTextColor
                }
                QQC2.Label {
                    x: -width / 2
                    y: 4
                    text: String(parent.modelData).replace("-", "−")
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                }
            }
        }
    }

    handle: Item {
        x: root.leftPadding + root.availableWidth * root.fraction(root.value)
        width: 0
        height: root.height

        // Current gate value above the marker, kept inside the meter at both ends.
        QQC2.Label {
            x: {
                const centered = -width / 2;
                const left = -parent.x + root.leftPadding;
                const right = root.width - root.rightPadding - parent.x - width;
                return Math.max(left, Math.min(right, centered));
            }
            y: 0
            text: root.dbText(root.value)
            font: Kirigami.Theme.smallFont
            color: root.gateColor
        }

        Rectangle {
            x: -width / 2
            y: root.trackY - 5
            width: 10
            height: root.trackHeight + 10
            radius: 3
            scale: root.pressed || root.hovered || root.visualFocus ? 1.15 : 1
            color: root.pressed ? root.gateColor : Kirigami.Theme.backgroundColor
            border.width: 2
            border.color: root.gateColor
            Behavior on scale {
                NumberAnimation {
                    duration: Kirigami.Units.shortDuration
                }
            }
        }

        Rectangle {
            visible: root.visualFocus
            x: -9
            y: root.trackY - 9
            width: 18
            height: root.trackHeight + 18
            radius: 5
            color: "transparent"
            border.width: 2
            border.color: Kirigami.Theme.focusColor
        }
    }
}
