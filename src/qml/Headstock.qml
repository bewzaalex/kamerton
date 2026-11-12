// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Shapes
import org.kde.kirigami as Kirigami

/// Les Paul style headstock; every tuner key is a button for its string, carrying its note, number and frequency.
/// The drawing is 522 × 514 units and only ever scales as a whole, so its proportions never change.
/// Like the VU meter it is hardware with its own colors (lacquer, binding, chrome); selection and progress use KDE roles.
Item {
    id: root

    property int leftCount: 3
    property int rightCount: 3
    property var strings: []
    property int selected: 0
    property int playing: -1 ///< string whose reference tone is playing
    property bool playable: false ///< clicking a key plays / stops its reference tone

    signal picked(int index)

    readonly property real artWidth: 522
    readonly property real artHeight: 514
    /// Pixels per drawing unit.
    readonly property real s: Math.min(width / artWidth, height / artHeight)
    readonly property real offsetX: (width - artWidth * s) / 2
    readonly property real offsetY: (height - artHeight * s) / 2

    readonly property int stringCount: strings.length
    readonly property int rows: Math.max(leftCount, rightCount)

    // Outline traced from a straight-on photo of a Les Paul Custom and smoothed: the left half, x from the
    // centre line and y down from the top humps, in the photo's pixels. The right half is its mirror image.
    readonly property var sidePoints: [[-102, 846], [-102, 800], [-106, 760], [-120, 712], [-160, 666], [-185, 642], [-189, 620],
                                       [-180, 520], [-168, 380], [-170, 220], [-180, 100], [-186, 41]]
    readonly property var topPoints: [[-186, 41], [-150, 39], [-110, 31.5], [-70, 15], [-30, 0], [0, 8]]
    readonly property real k: 105 / 186 ///< photo pixels to drawing units: a 210 units wide top
    readonly property real centerX: 261
    readonly property real topY: 6
    readonly property real nutY: topY + 846 * k
    readonly property real postOffset: 118 * k
    readonly property real keyWidth: 138
    readonly property real keyHeight: 52

    readonly property var side: sidePoints.map(p => [centerX + p[0] * k, topY + p[1] * k])
    readonly property string outline: {
        const top = topPoints.map(p => [centerX + p[0] * k, topY + p[1] * k]);
        const mirror = pts => pts.map(p => [2 * centerX - p[0], p[1]]).reverse();
        return `M ${side[0][0]} ${side[0][1]} ` + spline(side) + spline(top) + spline(mirror(top)) + spline(mirror(side)) + "Z";
    }

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

    /// Catmull-Rom through the points, as cubic Bézier segments.
    function spline(pts) {
        let d = "";
        for (let i = 0; i < pts.length - 1; ++i) {
            const p0 = pts[Math.max(0, i - 1)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[Math.min(pts.length - 1, i + 2)];
            d += `C ${p1[0] + (p2[0] - p0[0]) / 6} ${p1[1] + (p2[1] - p0[1]) / 6} `
               + `${p2[0] - (p3[0] - p1[0]) / 6} ${p2[1] - (p3[1] - p1[1]) / 6} ${p2[0]} ${p2[1]} `;
        }
        return d;
    }
    /// Rows of posts as on the photo, 187.5 photo pixels apart around the middle; more than three rows squeeze closer.
    function rowY(row) {
        const step = rows > 3 ? 137 : 187.5;
        return topY + (355.5 + (row - (rows - 1) / 2) * step) * k;
    }
    function postX(left) {
        return centerX + (left ? -postOffset : postOffset);
    }
    function nutX(index) {
        return centerX - 47.5 + index * (95 / Math.max(1, stringCount - 1));
    }
    /// Where the left edge of the outline is at height y.
    function edgeX(y) {
        for (let i = side.length - 1; i > 0; --i) {
            const [x1, y1] = side[i], [x0, y0] = side[i - 1];
            if (y >= y1 && y <= y0) {
                return x1 + (x0 - x1) * (y - y1) / (y0 - y1);
            }
        }
        return side[side.length - 1][0];
    }
    function stringPath(p) {
        const y = rowY(p.row);
        const x = postX(p.left);
        return `M ${x} ${y} L ${nutX(p.string)} ${nutY} L ${nutX(p.string)} ${artHeight} `;
    }
    /// Low strings are wound and drawn bronze, high ones plain steel.
    function wound(index) {
        return (strings[index]?.frequency ?? 0) < 180;
    }

    implicitWidth: Kirigami.Units.gridUnit * 24
    implicitHeight: implicitWidth * artHeight / artWidth

    // The drawing, in units, scaled as a whole.
    Item {
        x: root.offsetX
        y: root.offsetY
        width: root.artWidth
        height: root.artHeight
        scale: root.s
        transformOrigin: Item.TopLeft

        // Key shafts, from the keys to the edge.
        Repeater {
            model: root.pegs
            delegate: Rectangle {
                required property var modelData
                readonly property real edge: root.edgeX(root.rowY(modelData.row))
                readonly property real keyEdge: 4 + root.keyWidth - 2
                x: modelData.left ? keyEdge : 2 * root.centerX - edge - 4
                width: edge + 4 - keyEdge
                y: root.rowY(modelData.row) - 5
                height: 10
                gradient: Gradient {
                    GradientStop { position: 0; color: "#e4e6ea" }
                    GradientStop { position: 0.5; color: "#8e9299" }
                    GradientStop { position: 1; color: "#5d6067" }
                }
            }
        }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            // Fretboard below the nut, and its first fret.
            ShapePath {
                strokeColor: "transparent"
                fillColor: "#2b1f18"
                PathRectangle {
                    x: root.centerX - 57.6
                    y: root.nutY
                    width: 115.2
                    height: root.artHeight - root.nutY
                }
            }
            ShapePath {
                strokeColor: "#b9bcc2"
                strokeWidth: 2.5
                fillColor: "transparent"
                PathSvg {
                    path: `M ${root.centerX - 58} ${root.nutY + 20} H ${root.centerX + 58}`
                }
            }

            // Black lacquer face with a faint gloss.
            ShapePath {
                strokeColor: "transparent"
                fillGradient: LinearGradient {
                    x1: 0
                    y1: 0
                    x2: 0
                    y2: root.nutY
                    GradientStop { position: 0; color: "#202024" }
                    GradientStop { position: 1; color: "#0d0d0f" }
                }
                PathSvg {
                    path: root.outline
                }
            }
            ShapePath {
                strokeColor: "transparent"
                fillGradient: LinearGradient {
                    x1: 150
                    y1: 0
                    x2: 372
                    y2: 222
                    GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.09) }
                    GradientStop { position: 1; color: "transparent" }
                }
                PathSvg {
                    path: root.outline
                }
            }

            // Bell-shaped truss rod cover.
            ShapePath {
                fillColor: "#141416"
                strokeColor: "#e6d9b0"
                strokeWidth: 2
                PathSvg {
                    path: "M 261 312 C 246 312 243 324 243 338 C 243 373 240 411 234 437 C 230 453 222 463 212 469 "
                        + "L 310 469 C 300 463 292 453 288 437 C 282 411 279 373 279 338 C 279 324 276 312 261 312 Z"
                }
            }

            // Layered binding: cream, black, cream.
            ShapePath {
                fillColor: "transparent"
                strokeColor: "#e6d9b0"
                strokeWidth: 9
                PathSvg {
                    path: root.outline
                }
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: "#141416"
                strokeWidth: 5
                PathSvg {
                    path: root.outline
                }
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: "#e6d9b0"
                strokeWidth: 1.8
                PathSvg {
                    path: root.outline
                }
            }
        }

        // Cover screws.
        Repeater {
            model: [325, 459]
            delegate: Rectangle {
                required property real modelData
                x: root.centerX - 3
                y: modelData - 3
                width: 6
                height: 6
                radius: 3
                color: "#c9ccd1"
            }
        }

        // Tuner bushings and posts.
        Repeater {
            model: root.pegs
            delegate: Rectangle {
                required property var modelData
                x: root.postX(modelData.left) - 14
                y: root.rowY(modelData.row) - 14
                width: 28
                height: 28
                radius: 14
                border.width: 1
                border.color: "#55585e"
                gradient: Gradient {
                    GradientStop { position: 0; color: "#f4f5f7" }
                    GradientStop { position: 0.6; color: "#a3a7ae" }
                    GradientStop { position: 1; color: "#5f6269" }
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 17
                    height: 17
                    radius: width / 2
                    color: "#2a2b2f"
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 10.4
                    height: 10.4
                    radius: width / 2
                    color: "#d9dbdf"
                }
            }
        }

        // Nut.
        Rectangle {
            x: root.centerX - 60
            y: root.nutY - 5
            width: 120
            height: 10
            radius: 1.5
            color: "#efe7cf"
            border.width: 0.8
            border.color: "#c9bf9f"
        }

        // Strings: bronze wound ones, plain steel ones, and the chosen one in the selection color.
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "#a88a5c"
                strokeWidth: 1.9
                fillColor: "transparent"
                PathSvg {
                    path: root.pegs.filter(p => p.string !== root.selected && root.wound(p.string)).map(p => root.stringPath(p)).join(" ")
                }
            }
            ShapePath {
                strokeColor: "#c9cacd"
                strokeWidth: 1.3
                fillColor: "transparent"
                PathSvg {
                    path: root.pegs.filter(p => p.string !== root.selected && !root.wound(p.string)).map(p => root.stringPath(p)).join(" ")
                }
            }
            ShapePath {
                strokeColor: Kirigami.Theme.highlightColor
                strokeWidth: 2.6
                fillColor: "transparent"
                PathSvg {
                    path: root.pegs.filter(p => p.string === root.selected).map(p => root.stringPath(p)).join(" ")
                }
            }
        }
    }

    // Tuner keys, laid out in pixels so their text stays sharp.
    Repeater {
        model: root.pegs
        delegate: TunerKey {
            required property var modelData
            info: root.strings[modelData.string] ?? ({})
            selected: modelData.string === root.selected
            playing: modelData.string === root.playing
            playable: root.playable
            outerLeft: modelData.left
            x: root.offsetX + (modelData.left ? 4 : root.artWidth - 4 - root.keyWidth) * root.s
            y: root.offsetY + (root.rowY(modelData.row) - root.keyHeight / 2) * root.s
            width: root.keyWidth * root.s
            height: root.keyHeight * root.s
            onClicked: root.picked(modelData.string)
        }
    }

    /// A chrome tuner key: note on the outer side, string number and frequency towards the headstock.
    /// The chosen key is tinted with the selection color; a tuned string gets a check badge on its outer corner,
    /// and when strings are playable a play / stop badge sits on the inner corner.
    component TunerKey: QQC2.AbstractButton {
        id: key

        property var info: ({})
        property bool selected: false
        property bool playing: false
        property bool playable: false
        property bool outerLeft: true

        readonly property string noteName: (info.letter ?? "") + (info.octave ?? "")
        readonly property string frequencyText: Number(info.frequency ?? 0).toFixed(2)
        readonly property real u: root.s ///< pixels per drawing unit
        readonly property color ink: "#1d1f23"
        readonly property color inkMuted: "#454950"

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

        background: Item {
            // Glow around the chosen key.
            Rectangle {
                visible: key.selected
                anchors.fill: parent
                anchors.margins: -3 * key.u
                radius: height / 2
                color: "transparent"
                border.width: 6 * key.u
                border.color: Qt.alpha(Kirigami.Theme.highlightColor, 0.35)
            }
            // Chrome.
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                border.width: key.selected || key.visualFocus ? 2.5 * key.u : Math.max(1, 1.2 * key.u)
                border.color: key.visualFocus ? Kirigami.Theme.focusColor : key.selected ? Kirigami.Theme.highlightColor : "#6f737a"
                gradient: Gradient {
                    GradientStop { position: 0; color: "#fbfbfc" }
                    GradientStop { position: 0.45; color: "#cfd2d7" }
                    GradientStop { position: 0.56; color: "#a9adb4" }
                    GradientStop { position: 1; color: "#dcdee2" }
                }
            }
            // Selection tint, hover brightening.
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: key.selected ? Qt.alpha(Kirigami.Theme.highlightColor, 0.38)
                     : key.hovered ? Qt.rgba(1, 1, 1, 0.18)
                     : "transparent"
            }
            // Highlight along the top.
            Rectangle {
                x: 18 * key.u
                y: 6 * key.u
                width: parent.width - 36 * key.u
                height: 10 * key.u
                radius: height / 2
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.55) }
                    GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0) }
                }
            }
        }

        contentItem: Item {
            Row {
                x: 15 * key.u - key.leftPadding
                anchors.verticalCenter: parent.verticalCenter
                QQC2.Label {
                    id: letter
                    text: key.info.letter ?? ""
                    font.pixelSize: 27 * key.u
                    color: key.ink
                }
                QQC2.Label {
                    text: key.info.octave ?? ""
                    font.pixelSize: 14 * key.u
                    color: key.inkMuted
                    anchors.baseline: letter.baseline
                }
            }
            Column {
                x: parent.width + key.rightPadding - 15 * key.u - width
                anchors.verticalCenter: parent.verticalCenter
                QQC2.Label {
                    anchors.right: parent.right
                    text: i18nc("string number", "string %1", key.info.number ?? "")
                    font.pixelSize: 12.5 * key.u
                    color: key.inkMuted
                }
                QQC2.Label {
                    anchors.right: parent.right
                    text: i18nc("frequency", "%1 Hz", key.frequencyText)
                    font.pixelSize: 13.5 * key.u
                    font.features: { "tnum": 1 }
                    color: key.ink
                }
            }
        }

        Badge {
            u: key.u
            visible: key.info.tuned ?? false
            x: (key.outerLeft ? 18 : key.width / key.u - 18) * key.u - width / 2
            color: Kirigami.Theme.positiveTextColor
            glyph: "M 6.5 12.5 L 10.5 16.5 L 17.5 8.5"
            stroked: true
            glyphColor: "white"
        }

        Badge {
            u: key.u
            visible: key.playable
            x: (key.outerLeft ? key.width / key.u - 18 : 18) * key.u - width / 2
            color: key.playing ? Kirigami.Theme.highlightColor
                 : Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.15)
            glyph: key.playing ? "M 7.5 7.5 L 16.5 7.5 L 16.5 16.5 L 7.5 16.5 Z" : "M 9 6 L 18.5 12 L 9 18 Z"
            glyphColor: key.playing ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
        }
    }

    /// Round badge above a rounded end of the key, clear of its text, ringed with the panel color so it stands out.
    component Badge: Rectangle {
        id: badge
        property string glyph ///< SVG path in a 24 × 24 box
        property bool stroked: false
        property color glyphColor
        property real u: 1 ///< pixels per drawing unit
        y: -8 * badge.u - height / 2
        width: 28 * badge.u
        height: width
        radius: width / 2
        border.width: 2.5 * badge.u
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
