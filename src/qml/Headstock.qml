// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
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
    property bool playable: false ///< clicking a peg plays / stops its reference tone

    signal picked(int index)

    readonly property int rowHeight: 64
    readonly property int top0: 24
    readonly property int rows: Math.max(leftCount, rightCount)
    readonly property int totalHeight: top0 + rows * rowHeight + 60
    readonly property int nutY: totalHeight - 44
    readonly property int stringCount: strings.length
    // The art is drawn for 96 px pegs; wider fonts get wider pegs, and the pegs move outwards.
    readonly property int shapeWidth: 304
    readonly property int basePegWidth: 96
    readonly property int pegWidth: {
        let widest = basePegWidth;
        for (let i = 0; i < pegRepeater.count; ++i) {
            const peg = pegRepeater.itemAt(i);
            if (peg) {
                widest = Math.max(widest, peg.implicitWidth);
            }
        }
        return Math.ceil(widest);
    }
    readonly property int artWidth: shapeWidth + 2 * (pegWidth - basePegWidth)

    // Every color is derived from the KDE color scheme.
    readonly property color woodColor: Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.12)
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
        return left ? 124 : 180;
    }
    function nutX(index) {
        return 130 + index * (44 / Math.max(1, stringCount - 1));
    }
    function stringPath(p) {
        const y = pegY(p.row);
        const x = postX(p.left);
        return `M ${x} ${y} L ${nutX(p.string)} ${nutY} L ${nutX(p.string)} ${totalHeight} `;
    }

    implicitWidth: artWidth
    implicitHeight: totalHeight

    Shape {
        width: root.shapeWidth
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
                    return p.left ? `M ${root.basePegWidth} ${y} L ${root.postX(true) - 6} ${y}`
                                  : `M ${root.postX(false) + 6} ${y} L ${root.shapeWidth - root.basePegWidth} ${y}`;
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
                path: `M 126 ${h} L 126 ${n - 6} C 114 ${n - 30} 108 ${n - 50} 108 ${n - 80} L 108 ${t} Q 108 6 124 6 `
                    + `L 180 6 Q 196 6 196 ${t} L 196 ${n - 80} C 196 ${n - 50} 190 ${n - 30} 178 ${n - 6} L 178 ${h} Z`
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
            fillColor: Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.85)
            strokeColor: "transparent"
            PathRectangle {
                x: 126
                y: root.nutY - 3
                width: 52
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
        id: pegRepeater
        model: root.pegs
        delegate: StringButton {
            required property var modelData
            info: root.strings[modelData.string] ?? ({})
            selected: modelData.string === root.selected
            playing: modelData.string === root.playing
            playable: root.playable
            letterSize: 18
            x: (root.width - root.artWidth) / 2 + (modelData.left ? 0 : root.artWidth - root.pegWidth)
            y: root.pegY(modelData.row) - 22
            width: root.pegWidth
            height: 44
            onClicked: root.picked(modelData.string)
        }
    }
}
