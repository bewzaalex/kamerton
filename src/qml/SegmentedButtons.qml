// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Shapes
import org.kde.kirigami as Kirigami

/// Buttons joined into one block, all of the same width; the chosen one is underlined.
/// Each entry of `model` is { value, label, glyph }, where glyph is an SVG path in a 24 × 24 box.
Rectangle {
    id: root

    property var model: []
    property var value
    property string accessibleName
    /// Labels hidden, glyphs only (they move to tooltips), for narrow places.
    property bool iconsOnly: false

    signal picked(var value)

    readonly property color frameColor: Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, Kirigami.Theme.frameContrast)
    readonly property real cellWidth: {
        let widest = 0;
        for (let i = 0; i < cells.count; ++i) {
            const cell = cells.itemAt(i);
            if (cell) {
                widest = Math.max(widest, cell.implicitWidth);
            }
        }
        return Math.ceil(widest);
    }

    implicitWidth: row.implicitWidth + 2
    implicitHeight: Math.round(Kirigami.Units.gridUnit * 1.7)
    radius: Kirigami.Units.cornerRadius
    color: Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.04)
    border.width: 1
    border.color: frameColor
    opacity: enabled ? 1 : 0.5

    Accessible.role: Accessible.Grouping
    Accessible.name: accessibleName

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.margins: 1
        spacing: 0

        Repeater {
            id: cells
            model: root.model
            delegate: QQC2.AbstractButton {
                id: cell

                required property var modelData
                required property int index
                readonly property bool chosen: root.value === modelData.value

                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: root.cellWidth
                implicitWidth: root.iconsOnly ? Math.max(content.implicitWidth + Kirigami.Units.largeSpacing * 2, Kirigami.Units.gridUnit * 2.75)
                                              : content.implicitWidth + Kirigami.Units.largeSpacing * 2
                hoverEnabled: true
                focusPolicy: Qt.StrongFocus
                checkable: true
                checked: chosen
                text: modelData.label
                Accessible.role: Accessible.RadioButton
                onClicked: root.picked(modelData.value)

                QQC2.ToolTip.text: text
                QQC2.ToolTip.visible: root.iconsOnly && hovered
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay

                background: Item {
                    Rectangle {
                        anchors.fill: parent
                        color: cell.chosen ? Qt.alpha(Kirigami.Theme.highlightColor, 0.22)
                             : cell.down ? Qt.alpha(Kirigami.Theme.highlightColor, 0.15)
                             : cell.hovered ? Qt.alpha(Kirigami.Theme.highlightColor, 0.08)
                             : "transparent"
                    }
                    Rectangle {
                        visible: cell.index > 0
                        width: 1
                        height: parent.height
                        color: root.frameColor
                    }
                    Rectangle {
                        visible: cell.chosen
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 2
                        color: Kirigami.Theme.highlightColor
                    }
                    Rectangle {
                        visible: cell.visualFocus
                        anchors.fill: parent
                        color: "transparent"
                        border.width: 2
                        border.color: Kirigami.Theme.focusColor
                    }
                }

                contentItem: Item {
                    RowLayout {
                        id: content
                        anchors.centerIn: parent
                        spacing: Kirigami.Units.smallSpacing

                        Shape {
                            visible: (cell.modelData.glyph ?? "").length > 0
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small
                            Layout.preferredHeight: Kirigami.Units.iconSizes.small
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                scale: Qt.size(Kirigami.Units.iconSizes.small / 24, Kirigami.Units.iconSizes.small / 24)
                                fillColor: "transparent"
                                strokeColor: Kirigami.Theme.textColor
                                strokeWidth: 2
                                capStyle: ShapePath.RoundCap
                                joinStyle: ShapePath.RoundJoin
                                PathSvg {
                                    path: cell.modelData.glyph ?? ""
                                }
                            }
                        }
                        QQC2.Label {
                            visible: !root.iconsOnly
                            text: cell.text
                        }
                    }
                }
            }
        }
    }
}
