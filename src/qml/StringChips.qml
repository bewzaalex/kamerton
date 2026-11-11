// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

/// Two-column grid of string buttons for instruments without headstock art, highest string first.
GridLayout {
    id: root

    property var strings: []
    property int selected: 0
    property int playing: -1

    signal picked(int index)

    columns: 2
    columnSpacing: Kirigami.Units.largeSpacing
    rowSpacing: Kirigami.Units.largeSpacing
    uniformCellWidths: true

    Repeater {
        model: root.strings.length
        delegate: QQC2.AbstractButton {
            id: chip
            required property int index
            readonly property int stringIndex: root.strings.length - 1 - index
            readonly property var info: root.strings[stringIndex]
            readonly property bool isSelected: stringIndex === root.selected

            Layout.fillWidth: true
            implicitHeight: Kirigami.Units.gridUnit * 3
            hoverEnabled: true
            focusPolicy: Qt.StrongFocus

            Accessible.name: i18nc("@action:button string number, note, frequency", "String %1, %2%3, %4 Hz",
                                   info.number, info.letter, info.octave, info.frequency.toFixed(2))
            Accessible.checked: isSelected
            Accessible.checkable: true

            onClicked: root.picked(stringIndex)

            background: Rectangle {
                radius: height / 2
                color: chip.isSelected ? Qt.alpha(Kirigami.Theme.highlightColor, 0.22)
                     : chip.hovered ? Qt.alpha(Kirigami.Theme.highlightColor, 0.08)
                     : Kirigami.Theme.backgroundColor
                border.width: chip.isSelected || chip.visualFocus ? 2 : 1
                border.color: chip.isSelected || chip.visualFocus ? Kirigami.Theme.highlightColor
                            : Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.3)
            }

            contentItem: RowLayout {
                spacing: Kirigami.Units.smallSpacing
                Item {
                    implicitWidth: Kirigami.Units.smallSpacing
                }
                Row {
                    QQC2.Label {
                        id: letterLabel
                        text: chip.info.letter
                        font.pixelSize: 20
                        font.weight: Font.DemiBold
                    }
                    QQC2.Label {
                        text: chip.info.octave
                        font.pixelSize: 12
                        color: Kirigami.Theme.disabledTextColor
                        anchors.baseline: letterLabel.baseline
                    }
                }
                Item {
                    Layout.fillWidth: true
                }
                ColumnLayout {
                    spacing: 0
                    QQC2.Label {
                        Layout.alignment: Qt.AlignRight
                        text: i18nc("string number", "string %1", chip.info.number)
                        font: Kirigami.Theme.smallFont
                        color: Kirigami.Theme.disabledTextColor
                    }
                    QQC2.Label {
                        Layout.alignment: Qt.AlignRight
                        text: i18nc("frequency", "%1 Hz", chip.info.frequency.toFixed(2))
                        font: Kirigami.Theme.smallFont
                        color: Kirigami.Theme.disabledTextColor
                    }
                }
                Item {
                    implicitWidth: Kirigami.Units.smallSpacing
                }
            }

            Badge {
                visible: chip.stringIndex === root.playing
                x: -4
                y: -4
                color: Kirigami.Theme.highlightColor
                icon: "audio-volume-high"
            }
            Badge {
                visible: chip.info.tuned
                x: parent.width - width + 4
                y: -4
                color: Kirigami.Theme.positiveTextColor
                icon: "checkmark"
            }
        }
    }

    component Badge: Rectangle {
        property string icon
        implicitWidth: 18
        implicitHeight: 18
        radius: 9
        Kirigami.Icon {
            anchors.centerIn: parent
            width: 12
            height: 12
            source: parent.icon
            color: "white"
            isMask: true
        }
    }
}
