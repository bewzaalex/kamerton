// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Shapes
import org.kde.kirigami as Kirigami

/// Stylised headstock; every tuning peg is a button for its string.
Item {
    id: root

    property int leftCount: 3
    property int rightCount: 3
    property var strings: []
    property int selected: 0
    property int playing: -1 ///< string whose reference tone is playing

    signal picked(int index)

    readonly property int rowHeight: 64
    readonly property int top0: 24
    readonly property int rows: Math.max(leftCount, rightCount)
    readonly property int totalHeight: top0 + rows * rowHeight + 60
    readonly property int nutY: totalHeight - 44
    readonly property int stringCount: strings.length

    readonly property color woodColor: Kirigami.ColorUtils.tintWithAlpha(
        Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.12), "#8a6a4a", 0.25)
    readonly property color edgeColor: Kirigami.ColorUtils.linearInterpolation(woodColor, Kirigami.Theme.textColor, 0.2)
    readonly property color chromeColor: Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.55)
    readonly property color stringColor: Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.7)

    // Lowest strings go on the left side, nearest to the nut; the rest on the right, top to bottom.
    readonly property var pegs: {
        const result = [];
        for (let i = 0; i < leftCount; ++i) {
            result.push({ string: leftCount - 1 - i, row: i, left: true });
        }
        for (let j = 0; j < rightCount; ++j) {
            result.push({ string: leftCount + j, row: j, left: false });
        }
        return result.filter(p => p.string < stringCount);
    }

    function pegY(row) {
        return top0 + row * rowHeight + 22;
    }
    function postX(left) {
        return left ? 104 : 176;
    }
    function nutX(index) {
        return 116 + index * (48 / Math.max(1, stringCount - 1));
    }
    function stringPath(p) {
        const y = pegY(p.row);
        const x = postX(p.left);
        return `M ${x} ${y} L ${nutX(p.string)} ${nutY} L ${nutX(p.string)} ${totalHeight} `;
    }

    implicitWidth: 280
    implicitHeight: totalHeight

    Shape {
        width: 280
        height: root.totalHeight
        anchors.horizontalCenter: parent.horizontalCenter
        preferredRendererType: Shape.CurveRenderer

        // Tuner shafts.
        ShapePath {
            strokeColor: root.chromeColor
            strokeWidth: 4
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathSvg {
                path: root.pegs.map(p => {
                    const y = root.pegY(p.row);
                    return p.left ? `M 56 ${y} L ${root.postX(true) - 6} ${y}`
                                  : `M ${root.postX(false) + 6} ${y} L 224 ${y}`;
                }).join(" ")
            }
        }

        // Headstock body.
        ShapePath {
            fillColor: root.woodColor
            strokeColor: root.edgeColor
            strokeWidth: 1.5
            PathSvg {
                readonly property int n: root.nutY
                readonly property int h: root.totalHeight
                readonly property int t: root.top0
                path: `M 112 ${h} L 112 ${n - 6} C 96 ${n - 30} 84 ${n - 50} 84 ${n - 80} L 84 ${t} Q 84 6 104 6 `
                    + `L 176 6 Q 196 6 196 ${t} L 196 ${n - 80} C 196 ${n - 50} 184 ${n - 30} 168 ${n - 6} L 168 ${h} Z`
            }
        }

        // Strings.
        ShapePath {
            strokeColor: root.stringColor
            strokeWidth: 1.4
            fillColor: "transparent"
            PathSvg {
                path: root.pegs.filter(p => p.string !== root.selected).map(p => root.stringPath(p)).join(" ")
            }
        }
        ShapePath {
            strokeColor: Kirigami.Theme.highlightColor
            strokeWidth: 2.4
            fillColor: "transparent"
            PathSvg {
                path: root.pegs.filter(p => p.string === root.selected).map(p => root.stringPath(p)).join(" ")
            }
        }

        // Nut.
        ShapePath {
            fillColor: Kirigami.ColorUtils.linearInterpolation("#f6f2e8", Kirigami.Theme.backgroundColor, 0.1)
            strokeColor: "transparent"
            PathRectangle {
                x: 110
                y: root.nutY - 3
                width: 60
                height: 6
                radius: 1
            }
        }

        // Tuner posts.
        ShapePath {
            fillColor: root.chromeColor
            strokeColor: root.edgeColor
            strokeWidth: 1
            PathSvg {
                path: root.pegs.map(p => {
                    const x = root.postX(p.left);
                    const y = root.pegY(p.row);
                    return `M ${x - 7} ${y} a 7 7 0 1 0 14 0 a 7 7 0 1 0 -14 0`;
                }).join(" ")
            }
        }
    }

    Repeater {
        model: root.pegs
        delegate: QQC2.AbstractButton {
            id: peg
            required property var modelData
            readonly property var info: root.strings[modelData.string] ?? ({})
            readonly property bool isSelected: modelData.string === root.selected

            x: (root.width - 280) / 2 + (modelData.left ? 0 : 224)
            y: root.pegY(modelData.row) - 22
            width: 56
            height: 44
            hoverEnabled: true
            focusPolicy: Qt.StrongFocus

            Accessible.name: i18nc("@action:button string number, note, frequency", "String %1, %2%3, %4 Hz",
                                   info.number, info.letter, info.octave, Number(info.frequency).toFixed(2))
            Accessible.checked: isSelected
            Accessible.checkable: true

            QQC2.ToolTip.text: i18nc("@info:tooltip string number, frequency", "String %1 · %2 Hz", info.number, Number(info.frequency).toFixed(2))
            QQC2.ToolTip.visible: hovered
            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay

            onClicked: root.picked(modelData.string)

            background: Rectangle {
                radius: height / 2
                color: peg.isSelected ? Qt.alpha(Kirigami.Theme.highlightColor, 0.22)
                     : peg.hovered ? Qt.alpha(Kirigami.Theme.highlightColor, 0.08)
                     : Kirigami.Theme.backgroundColor
                border.width: peg.isSelected || peg.visualFocus ? 2 : 1
                border.color: peg.isSelected || peg.visualFocus ? Kirigami.Theme.highlightColor
                            : Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.3)
            }

            contentItem: Item {
                Row {
                    anchors.centerIn: parent
                    spacing: 1
                    QQC2.Label {
                        id: pegLetter
                        text: peg.info.letter ?? ""
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                    }
                    QQC2.Label {
                        text: peg.info.octave ?? ""
                        font.pixelSize: 11
                        color: Kirigami.Theme.disabledTextColor
                        anchors.baseline: pegLetter.baseline
                    }
                }
            }

            Badge {
                visible: peg.modelData.string === root.playing
                x: -4
                y: -4
                color: Kirigami.Theme.highlightColor
                icon: "audio-volume-high"
            }
            Badge {
                visible: peg.info.tuned ?? false
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
