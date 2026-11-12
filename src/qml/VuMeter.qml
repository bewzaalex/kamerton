// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Effects
import QtQuick.Shapes
import org.kde.kirigami as Kirigami

/// Analog VU meter for the needle display: ±50 cents, a face lit by a bulb behind glass,
/// an "In tune" LED under the glass, and the note with its frequencies under the window.
/// The meter keeps the golden ratio and scales with the space it gets.
///
/// Colors come from the KDE color scheme, except for what KDE has no role for: the lamp-lit face,
/// the ink printed on it, the needle shadow and the green LED.
Item {
    id: root

    property real cents: 0
    property bool active: false
    property bool inTune: false
    property string noteLetter
    property string noteOctave
    property real frequency: 0
    property string targetText

    readonly property real goldenRatio: 1.618
    readonly property color ink: "#2a1c10"
    readonly property color inkRed: "#b5281e"
    readonly property color inkGreen: "#2f7d3a"

    readonly property bool darkScheme: luminance(Kirigami.Theme.textColor) > luminance(Kirigami.Theme.backgroundColor)
    // Bezel: the view color in dark schemes, a softened text color in light ones, never hard black.
    readonly property color frameTop: darkScheme ? mix(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.1)
                                                 : mix(Kirigami.Theme.textColor, Kirigami.Theme.backgroundColor, 0.42)
    readonly property color frameBottom: darkScheme ? Kirigami.Theme.backgroundColor
                                                    : mix(Kirigami.Theme.textColor, Kirigami.Theme.backgroundColor, 0.3)
    readonly property color frameEdge: darkScheme ? Qt.rgba(0, 0, 0, 0.55)
                                                  : mix(Kirigami.Theme.textColor, Kirigami.Theme.backgroundColor, 0.2)

    // With no sound the needle sinks past −50 to its stop, slowly, like a real meter.
    property real needleCents: active ? Math.max(-50, Math.min(50, cents)) : -60
    Behavior on needleCents {
        SpringAnimation {
            spring: 3
            damping: 0.4
            epsilon: 0.05
        }
    }

    function luminance(c) {
        return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
    }
    function mix(a, b, t) {
        return Kirigami.ColorUtils.linearInterpolation(a, b, t);
    }

    implicitWidth: Kirigami.Units.gridUnit * 30
    implicitHeight: implicitWidth / goldenRatio

    Accessible.role: Accessible.Indicator
    Accessible.name: active ? i18nc("@info accessible note and cents", "%1%2, %3 cents", noteLetter, noteOctave, cents.toFixed(1))
                            : i18nc("@info accessible", "No signal")

    Item {
        id: meter

        /// One hundredth of the meter's width: every size inside scales with it.
        readonly property real u: width / 100

        anchors.centerIn: parent
        width: Math.min(root.width, root.height * root.goldenRatio)
        height: width / root.goldenRatio

        // Case
        Rectangle {
            id: plate
            Kirigami.Theme.colorSet: Kirigami.Theme.Button
            Kirigami.Theme.inherit: false
            anchors.fill: parent
            radius: Kirigami.Units.cornerRadius * 2
            border.width: 1
            border.color: Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, Kirigami.Theme.frameContrast)
            gradient: Gradient {
                GradientStop { position: 0; color: Kirigami.ColorUtils.linearInterpolation(plate.Kirigami.Theme.backgroundColor, plate.Kirigami.Theme.textColor, 0.06) }
                GradientStop { position: 1; color: plate.Kirigami.Theme.backgroundColor }
            }
        }

        Column {
            anchors.fill: parent
            anchors.margins: meter.u * 1.8
            spacing: meter.u * 1.8

            // Bezel around the window
            Rectangle {
                id: bezel
                width: parent.width
                height: parent.height - info.height - parent.spacing
                radius: Kirigami.Units.cornerRadius
                border.width: 1
                border.color: root.frameEdge
                gradient: Gradient {
                    GradientStop { position: 0; color: root.frameTop }
                    GradientStop { position: 1; color: root.frameBottom }
                }

                Item {
                    id: face
                    anchors.fill: parent
                    anchors.margins: meter.u * 0.9
                    clip: true

                    // Scale drawing: 600 × 250 units, fitted and centred in the window.
                    readonly property real s: Math.min(width / 600, height / 250)
                    readonly property real ox: (width - 600 * s) / 2
                    readonly property real oy: (height - 250 * s) / 2

                    // The bulb behind the pivot: warm amber falling off to brown corners, with a hot spot.
                    // Gradients are drawn in their own unit boxes and stretched to the face, which makes them elliptical.
                    LampLight {
                        target: Qt.size(face.width, face.height)
                        boxHeight: 695.65
                        centerRadius: 800
                        stops: [[0, "#ffd998"], [0.32, "#f5bb6a"], [0.6, "#df9748"], [0.84, "#b06a2e"], [1, "#7c4521"]]
                    }
                    LampLight {
                        target: Qt.size(face.width, face.height)
                        boxHeight: 714.29
                        centerRadius: 300
                        stops: [[0, Qt.rgba(1, 0.973, 0.871, 0.95)], [0.45, Qt.rgba(1, 0.91, 0.714, 0.55)], [1, Qt.rgba(1, 0.863, 0.627, 0)]]
                    }

                    // The window is recessed: the frame shades the top and the sides of the face.
                    Rectangle {
                        width: parent.width
                        height: meter.u * 1.4
                        gradient: Gradient {
                            GradientStop { position: 0; color: Qt.rgba(0.18, 0.09, 0.02, 0.5) }
                            GradientStop { position: 1; color: "transparent" }
                        }
                    }
                    Rectangle {
                        width: meter.u * 1.1
                        height: parent.height
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Qt.rgba(0.18, 0.09, 0.02, 0.4) }
                            GradientStop { position: 1; color: "transparent" }
                        }
                    }
                    Rectangle {
                        anchors.right: parent.right
                        width: meter.u * 1.1
                        height: parent.height
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: "transparent" }
                            GradientStop { position: 1; color: Qt.rgba(0.18, 0.09, 0.02, 0.4) }
                        }
                    }

                    ScaleArt {
                        x: face.ox
                        y: face.oy
                        s: face.s
                    }

                    // Needle, with a soft shadow on the face.
                    Item {
                        id: needleLayer
                        anchors.fill: parent
                        visible: false

                        Rectangle {
                            id: needle
                            width: 2.2 * face.s
                            height: 345 * face.s
                            x: face.ox + 300 * face.s - width / 2
                            y: face.oy + 400 * face.s - height
                            color: root.ink
                            antialiasing: true
                            transform: Rotation {
                                origin.x: needle.width / 2
                                origin.y: needle.height
                                angle: root.needleCents * 0.8
                            }
                        }
                    }
                    MultiEffect {
                        source: needleLayer
                        anchors.fill: needleLayer
                        shadowEnabled: true
                        shadowColor: Qt.rgba(0.24, 0.11, 0.02, 0.42)
                        shadowHorizontalOffset: 6 * face.s
                        shadowVerticalOffset: 4 * face.s
                        shadowBlur: 0.3
                    }

                    // In tune LED under the glass, top right.
                    Row {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.topMargin: meter.u * 2.8
                        anchors.rightMargin: meter.u * 3
                        spacing: meter.u * 0.9

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: i18nc("@info printed next to the lamp", "IN TUNE")
                            color: root.ink
                            font.pixelSize: Math.max(12, meter.u * 2.5)
                            font.weight: Font.Bold
                            font.letterSpacing: Math.max(12, meter.u * 2.5) * 0.125
                        }
                        Led {
                            anchors.verticalCenter: parent.verticalCenter
                            size: meter.u * 2.1
                            on: root.inTune
                        }
                    }

                    // Glass: a faint glare over the upper left, and the clear acrylic edge catching the lamp.
                    Glare {
                        anchors.fill: parent
                    }
                    Rectangle {
                        width: parent.width
                        height: parent.height * 0.55
                        gradient: Gradient {
                            GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.1) }
                            GradientStop { position: 1; color: "transparent" }
                        }
                    }
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.width: meter.u * 0.55
                        border.color: Qt.rgba(1, 0.973, 0.902, 0.28)
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: meter.u * 0.55
                        color: Qt.rgba(1, 0.965, 0.871, 0.35)
                    }
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: meter.u * 0.55
                        color: "transparent"
                        border.width: 1
                        border.color: Qt.rgba(0.27, 0.16, 0.05, 0.35)
                    }
                }
            }

            // Under the window: frequency and target, the note, cents and what to do.
            Item {
                id: info
                width: parent.width
                height: noteRow.implicitHeight

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: meter.u * 0.9
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: meter.u * 0.4
                    opacity: root.active ? 1 : 0.35

                    BigValue {
                        value: root.frequency.toFixed(2)
                        unit: i18nc("unit of frequency", "Hz")
                    }
                    SmallLine {
                        text: root.targetText
                    }
                }

                Row {
                    id: noteRow
                    anchors.horizontalCenter: parent.horizontalCenter
                    opacity: root.active ? 1 : 0.35

                    QQC2.Label {
                        id: letter
                        text: root.noteLetter
                        font.pixelSize: meter.u * 12
                        lineHeight: 0.9
                    }
                    QQC2.Label {
                        text: root.noteOctave
                        font.pixelSize: meter.u * 4
                        color: Kirigami.Theme.disabledTextColor
                        anchors.baseline: letter.baseline
                    }
                }

                Column {
                    anchors.right: parent.right
                    anchors.rightMargin: meter.u * 0.9
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: meter.u * 0.4

                    BigValue {
                        anchors.right: parent.right
                        opacity: root.active ? 1 : 0.35
                        value: {
                            if (!root.active) {
                                return "--.-";
                            }
                            const sign = root.cents > 0.05 ? "+" : root.cents < -0.05 ? "−" : "";
                            return sign + Math.abs(root.cents).toFixed(1);
                        }
                        unit: i18nc("unit of cents", "¢")
                    }
                    SmallLine {
                        anchors.right: parent.right
                        // The LED says "in tune"; this line only says what to do.
                        text: !root.active ? i18nc("@info tuning status", "Waiting for a sound…")
                            : root.inTune ? " "
                            : root.cents < 0 ? i18nc("@info tuning status", "Too low · tighten")
                            : i18nc("@info tuning status", "Too high · loosen")
                    }
                }
            }
        }
    }

    component BigValue: Row {
        property string value
        property string unit
        spacing: meter.u * 0.6
        QQC2.Label {
            id: big
            text: parent.value
            font.pixelSize: Math.max(20, meter.u * 4)
            font.features: { "tnum": 1 }
        }
        QQC2.Label {
            text: parent.unit
            font.pixelSize: Math.max(12, meter.u * 2)
            color: Kirigami.Theme.disabledTextColor
            anchors.baseline: big.baseline
        }
    }

    component SmallLine: QQC2.Label {
        font.pixelSize: Math.max(12, meter.u * 1.8)
        font.features: { "tnum": 1 }
        color: Kirigami.Theme.disabledTextColor
    }

    /// The printed scale in 600 × 250 units, `s` pixels per unit. The pivot is below the window at (300, 400).
    component ScaleArt: Item {
        id: art

        property real s: 1

        readonly property real k: 0.8 ///< degrees per cent
        readonly property real radius: 300

        function polar(r, deg) {
            const a = deg * Math.PI / 180;
            return [300 + r * Math.sin(a), 400 - r * Math.cos(a)];
        }
        function arc(r, c0, c1) {
            const p = polar(r, c0 * k), q = polar(r, c1 * k);
            return `M ${p[0]} ${p[1]} A ${r} ${r} 0 0 1 ${q[0]} ${q[1]} `;
        }
        function ticks(values, r0, r1) {
            return values.map(v => {
                const p = polar(r0, v * k), q = polar(r1, v * k);
                return `M ${p[0]} ${p[1]} L ${q[0]} ${q[1]}`;
            }).join(" ");
        }
        function range(a, b, step) {
            const out = [];
            for (let v = a; v <= b; v += step) {
                out.push(v);
            }
            return out;
        }

        width: 600 * s
        height: 250 * s

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            Ink {
                unit: art.s
                strokeWidth: 4
                path: art.arc(art.radius, -30, 30)
            }
            Ink {
                unit: art.s
                strokeWidth: 7
                strokeColor: root.inkRed
                path: art.arc(art.radius + 1.5, -50, -30) + art.arc(art.radius + 1.5, 30, 50)
            }
            Ink {
                unit: art.s
                strokeWidth: 5
                strokeColor: root.inkGreen
                path: art.arc(art.radius - 11, -3, 3)
            }
            Ink {
                unit: art.s
                strokeWidth: 2.6
                path: art.ticks([-20, -10, 0, 10, 20], art.radius, art.radius + 18)
            }
            Ink {
                unit: art.s
                strokeWidth: 2.6
                strokeColor: root.inkRed
                path: art.ticks([-50, -40, -30, 30, 40, 50], art.radius, art.radius + 18)
            }
            Ink {
                unit: art.s
                strokeWidth: 1.8
                path: art.ticks(art.range(-45, 45, 10), art.radius, art.radius + 10)
            }
            Ink {
                unit: art.s
                strokeWidth: 1.1
                path: art.ticks(art.range(-38, 38, 2), art.radius - 28, art.radius - 20)
            }
        }

        Repeater {
            model: [-50, -30, -20, -10, 0, 10, 20, 30, 50]
            delegate: Text {
                required property int modelData
                readonly property var point: art.polar(art.radius + 34, modelData * art.k)
                text: modelData > 0 ? "+" + modelData : modelData < 0 ? "−" + (-modelData) : "0"
                color: Math.abs(modelData) >= 30 ? root.inkRed : root.ink
                font.pixelSize: 19 * art.s
                font.weight: Font.DemiBold
                x: point[0] * art.s - width / 2
                y: point[1] * art.s - height / 2
            }
        }

        Print {
            unit: art.s
            cx: 74
            cy: 205
            text: "♭"
            font.pixelSize: 26 * art.s
        }
        Print {
            unit: art.s
            cx: 526
            cy: 205
            text: "♯"
            font.pixelSize: 26 * art.s
        }
        Print {
            unit: art.s
            cx: 300
            cy: 150
            text: i18nc("@info printed on the meter scale", "CENTS")
            font.pixelSize: 16 * art.s
            font.weight: Font.Bold
            font.letterSpacing: 2 * art.s
        }
    }

    /// Light from the bulb at the bottom centre: a radial gradient in a 1000-wide box whose height makes it
    /// circular there, stretched over the whole face.
    component LampLight: Shape {
        id: lamp
        property real boxHeight: 1000
        property real centerRadius: 500
        property var stops: []
        property size target: Qt.size(1000, boxHeight)

        width: 1000
        height: boxHeight
        transform: Scale {
            xScale: lamp.target.width / 1000
            yScale: lamp.target.height / lamp.boxHeight
        }

        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: 500
                centerY: lamp.boxHeight
                centerRadius: lamp.centerRadius
                focalX: 500
                focalY: lamp.boxHeight
                focalRadius: 0
                stops: lamp.stops.map(stop => gradientStop.createObject(lamp, { position: stop[0], color: stop[1] }))
            }
            PathSvg {
                path: `M 0 0 H 1000 V ${lamp.boxHeight} H 0 Z`
            }
        }

        Component {
            id: gradientStop
            GradientStop {}
        }
    }

    /// A stroke printed on the scale, drawn in 600 × 250 units scaled by `unit`.
    component Ink: ShapePath {
        property real unit: 1
        property alias path: svg.path
        scale: Qt.size(unit, unit)
        fillColor: "transparent"
        strokeColor: root.ink
        capStyle: ShapePath.FlatCap
        PathSvg {
            id: svg
        }
    }

    /// Text printed on the scale, centred on (cx, cy) in scale units.
    component Print: Text {
        property real unit: 1
        property real cx
        property real cy
        color: root.ink
        x: cx * unit - width / 2
        y: cy * unit - height / 2
    }

    /// A domed LED in its socket: unlit green glass when off, bright green with a glow when on.
    component Led: Item {
        id: led

        property real size: 16
        property bool on: false

        width: size
        height: size

        // Glow on the face around the lit LED.
        Rectangle {
            id: glowDisc
            width: led.size * 1.4
            height: width
            radius: width / 2
            color: "#5aff78"
            visible: false
        }
        MultiEffect {
            source: glowDisc
            anchors.centerIn: parent
            width: glowDisc.width
            height: glowDisc.height
            blurEnabled: true
            blurMax: 32
            blur: 1
            opacity: led.on ? 0.95 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Kirigami.Units.shortDuration
                }
            }
        }

        // Socket
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Qt.rgba(0.24, 0.13, 0.04, 0.35)
        }

        // Dome
        Shape {
            id: dome
            readonly property real r: led.size / 2 - led.size * 0.1
            anchors.centerIn: parent
            width: r * 2
            height: r * 2
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: led.on ? dome.r : dome.r * 0.76
                    centerY: led.on ? dome.r * 1.16 : dome.r * 0.64
                    centerRadius: dome.r * (led.on ? 1.5 : 1.84)
                    focalX: centerX
                    focalY: centerY
                    focalRadius: 0
                    GradientStop { position: 0; color: led.on ? "#c8ffc8" : "#a3c286" }
                    GradientStop { position: led.on ? 0.16 : 0.24; color: led.on ? "#5dff70" : "#5d874c" }
                    GradientStop { position: led.on ? 0.42 : 0.62; color: led.on ? "#1ee63b" : "#3b5f32" }
                    GradientStop { position: led.on ? 0.74 : 0.8; color: led.on ? "#0c9e26" : "#2e4c29" }
                    GradientStop { position: 1; color: led.on ? "#075f17" : "#284424" }
                }
                PathAngleArc {
                    centerX: dome.r
                    centerY: dome.r
                    radiusX: dome.r
                    radiusY: dome.r
                    startAngle: 0
                    sweepAngle: 360
                }
            }
        }

        // Reflections on the glass dome, the same whether it is lit or not.
        Rectangle {
            x: led.size * 0.28
            y: led.size * 0.2
            width: led.size * 0.32
            height: led.size * 0.22
            radius: height / 2
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.75) }
                GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0.1) }
            }
        }
        Rectangle {
            x: led.size * 0.36
            y: led.size * 0.72
            width: led.size * 0.28
            height: led.size * 0.1
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.25)
        }
    }

    /// A faint diagonal glare over the upper left of the glass, ending in a soft edge.
    component Glare: Shape {
        id: glare

        // The glare's edge runs at 28° from vertical and crosses the top at 38 % of the gradient line.
        readonly property real dx: 0.883
        readonly property real dy: 0.469
        readonly property real reach: 0.385 * (width * dx + height * dy)
        readonly property real topX: reach / dx
        readonly property real bottomX: Math.max(0, (reach - height * dy) / dx)

        ShapePath {
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: 0
                y1: 0
                x2: glare.reach * glare.dx
                y2: glare.reach * glare.dy
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.17) }
                GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0.09) }
            }
            PathSvg {
                path: glare.reach > glare.height * glare.dy
                    ? `M 0 0 L ${glare.topX} 0 L ${glare.bottomX} ${glare.height} L 0 ${glare.height} Z`
                    : `M 0 0 L ${glare.topX} 0 L 0 ${glare.reach / glare.dy} Z`
            }
        }
    }
}
