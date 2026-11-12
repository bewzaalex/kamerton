// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

/// Two-column grid of string buttons for instruments without headstock art, highest string first.
GridLayout {
    id: root

    property var strings: []
    property int selected: 0
    property int playing: -1
    property bool playable: false

    signal picked(int index)

    columns: 2
    columnSpacing: Kirigami.Units.largeSpacing
    rowSpacing: Kirigami.Units.largeSpacing
    uniformCellWidths: true

    Repeater {
        model: root.strings.length
        delegate: StringButton {
            required property int index
            readonly property int stringIndex: root.strings.length - 1 - index

            Layout.fillWidth: true
            implicitHeight: Kirigami.Units.gridUnit * 3
            info: root.strings[stringIndex]
            selected: stringIndex === root.selected
            playing: stringIndex === root.playing
            playable: root.playable
            onClicked: root.picked(stringIndex)
        }
    }
}
