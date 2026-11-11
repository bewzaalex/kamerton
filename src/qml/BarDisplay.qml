// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

/// LED bar: 21 segments from −50 to +50 cents, green in the middle.
Item {
    id: bar

    property real cents: 0
    property bool active: false
    property real inTuneZone: 3

    property real shown: active ? Math.max(-50, Math.min(50, cents)) : 0
    Behavior on shown {
        SmoothedAnimation {
            velocity: 200
        }
    }

    implicitWidth: 400
    implicitHeight: column.implicitHeight

    Accessible.role: Accessible.Indicator
    Accessible.name: active ? i18nc("@info accessible", "%1 cents", cents.toFixed(1)) : i18nc("@info accessible", "No signal")

    ColumnLayout {
        id: column
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width, Kirigami.Units.gridUnit * 36)
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 64
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: 21
                delegate: Rectangle {
                    required property int index
                    readonly property int value: index * 5 - 50
                    readonly property real distance: Math.abs(value - bar.shown)
                    readonly property color zoneColor: Math.abs(value) <= Math.max(bar.inTuneZone, 2.5) ? Kirigami.Theme.positiveTextColor
                                                     : Math.abs(value) <= 15 ? Kirigami.Theme.neutralTextColor
                                                     : Kirigami.Theme.negativeTextColor
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredHeight: 64 - Math.abs(value) * 0.5
                    radius: 3
                    color: bar.active && distance <= 7.5 ? zoneColor
                         : Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.15)
                    opacity: bar.active && distance > 2.5 && distance <= 7.5 ? 0.4 : 1.0
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Repeater {
                model: ["−50 ¢", "−25", "0", "+25", "+50 ¢"]
                delegate: QQC2.Label {
                    required property string modelData
                    required property int index
                    Layout.fillWidth: true
                    horizontalAlignment: index === 0 ? Text.AlignLeft : index === 4 ? Text.AlignRight : Text.AlignHCenter
                    text: modelData
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                }
            }
        }
    }
}
