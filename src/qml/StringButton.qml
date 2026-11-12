// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Shapes
import org.kde.kirigami as Kirigami

/// One string: note on the left, string number and frequency on the right.
/// Badges on the top edge show that the string is tuned and, when playable, play / stop its reference tone.
QQC2.AbstractButton {
    id: root

    property var info: ({})
    property bool selected: false
    property bool playing: false
    property bool playable: false
    property int letterSize: 20
    /// The pegs are narrow: string number and frequency use a fixed small size that fits them.
    readonly property int detailSize: Math.round(letterSize * 0.56)
    /// Keeps the text clear of the rounded ends.
    readonly property int sidePadding: Math.round(height * 0.3)

    readonly property string noteName: (info.letter ?? "") + (info.octave ?? "")
    readonly property string frequencyText: Number(info.frequency ?? 0).toFixed(2)

    hoverEnabled: true
    focusPolicy: Qt.StrongFocus

    Accessible.name: i18nc("@action:button string number, note, frequency", "String %1, %2, %3 Hz", info.number, noteName, frequencyText)
    Accessible.description: !playable ? ""
        : playing ? i18nc("@info accessible", "Stop the reference tone")
        : i18nc("@info accessible", "Play the reference tone")
    Accessible.checked: selected
    Accessible.checkable: true

    QQC2.ToolTip.text: playing ? i18nc("@info:tooltip", "Stop %1 (Space)", noteName) : i18nc("@info:tooltip", "Play %1 (Space)", noteName)
    QQC2.ToolTip.visible: playable && hovered
    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay

    background: Rectangle {
        radius: height / 2
        color: root.selected ? Qt.alpha(Kirigami.Theme.highlightColor, 0.22)
             : root.hovered ? Qt.alpha(Kirigami.Theme.highlightColor, 0.08)
             : Kirigami.Theme.backgroundColor
        border.width: root.selected || root.visualFocus ? 2 : 1
        border.color: root.selected || root.visualFocus ? Kirigami.Theme.highlightColor
                    : Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.3)
    }

    contentItem: RowLayout {
        spacing: Kirigami.Units.smallSpacing

        Row {
            Layout.leftMargin: root.sidePadding
            QQC2.Label {
                id: letter
                text: root.info.letter ?? ""
                font.pixelSize: root.letterSize
                font.weight: Font.DemiBold
            }
            QQC2.Label {
                text: root.info.octave ?? ""
                font.pixelSize: Math.round(root.letterSize * 0.6)
                color: Kirigami.Theme.disabledTextColor
                anchors.baseline: letter.baseline
            }
        }

        Item {
            Layout.fillWidth: true
        }

        ColumnLayout {
            Layout.rightMargin: root.sidePadding
            spacing: 0
            QQC2.Label {
                Layout.alignment: Qt.AlignRight
                text: i18nc("string number", "string %1", root.info.number ?? "")
                font.pixelSize: root.detailSize
                color: Kirigami.Theme.disabledTextColor
            }
            QQC2.Label {
                Layout.alignment: Qt.AlignRight
                text: i18nc("frequency", "%1 Hz", root.frequencyText)
                font.pixelSize: root.detailSize
                font.features: { "tnum": 1 }
                color: Kirigami.Theme.disabledTextColor
            }
        }
    }

    Badge {
        visible: root.info.tuned ?? false
        x: Kirigami.Units.largeSpacing
        color: Kirigami.Theme.positiveTextColor
        glyph: "M 6.5 12.5 L 10.5 16.5 L 17.5 8.5"
        stroked: true
        glyphColor: Kirigami.Theme.highlightedTextColor
    }

    Badge {
        visible: root.playable
        x: root.width - width - Kirigami.Units.largeSpacing
        color: root.playing ? Kirigami.Theme.highlightColor
             : Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.15)
        glyph: root.playing ? "M 7.5 7.5 L 16.5 7.5 L 16.5 16.5 L 7.5 16.5 Z" : "M 9 6 L 18.5 12 L 9 18 Z"
        glyphColor: root.playing ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
    }

    /// Round badge sitting on the top edge, ringed with the panel color so it stands out.
    /// The glyph is drawn rather than taken from the icon theme: themed media icons are often
    /// outlined circles that become unreadable at this size.
    component Badge: Rectangle {
        id: badge
        property string glyph   ///< SVG path in a 24 × 24 box
        property bool stroked: false
        property color glyphColor
        y: -height / 2
        implicitWidth: Kirigami.Units.gridUnit
        implicitHeight: implicitWidth
        radius: width / 2
        border.width: 2
        border.color: Kirigami.Theme.backgroundColor
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                scale: Qt.size(badge.width / 24, badge.height / 24)
                fillColor: badge.stroked ? "transparent" : badge.glyphColor
                strokeColor: badge.stroked ? badge.glyphColor : "transparent"
                strokeWidth: badge.stroked ? 3.2 : 0
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathSvg {
                    path: badge.glyph
                }
            }
        }
    }
}
