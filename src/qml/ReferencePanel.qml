// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import io.github.bewzaalex.kamerton

/// Reference tone settings for the side panel. Strings are played by clicking them;
/// only the chromatic tuner, which has no strings, gets its own play button and note picker.
ColumnLayout {
    id: root

    spacing: Kirigami.Units.largeSpacing
    opacity: enabled ? 1 : 0.45

    Kirigami.Heading {
        level: 4
        text: i18nc("@title", "Reference tone")
        Layout.fillWidth: true
    }

    RowLayout {
        visible: TunerController.chromatic
        Layout.fillWidth: true
        spacing: Kirigami.Units.largeSpacing

        QQC2.AbstractButton {
            id: playButton
            implicitWidth: Kirigami.Units.gridUnit * 3
            implicitHeight: implicitWidth
            hoverEnabled: true
            focusPolicy: Qt.StrongFocus
            text: TunerController.playing ? i18nc("@action:button", "Stop reference tone") : i18nc("@action:button", "Play reference tone")
            Accessible.name: text
            onClicked: TunerController.playing = !TunerController.playing

            QQC2.ToolTip.text: i18nc("@info:tooltip", "%1 (Space)", text)
            QQC2.ToolTip.visible: hovered
            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay

            background: Rectangle {
                radius: width / 2
                color: TunerController.playing ? Qt.alpha(Kirigami.Theme.highlightColor, 0.25)
                     : playButton.hovered ? Qt.alpha(Kirigami.Theme.highlightColor, 0.1)
                     : Kirigami.Theme.backgroundColor
                border.width: 2
                border.color: root.enabled ? Kirigami.Theme.highlightColor
                            : Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.3)
            }
            contentItem: Item {
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: Kirigami.Units.iconSizes.smallMedium
                    height: width
                    source: TunerController.playing ? "media-playback-stop" : "media-playback-start"
                }
            }
        }

        QQC2.ToolButton {
            icon.name: "go-previous"
            text: i18nc("@action:button", "Semitone down")
            display: QQC2.AbstractButton.IconOnly
            onClicked: TunerController.shiftReference(-1)
        }

        ColumnLayout {
            spacing: 0
            Layout.fillWidth: true
            Row {
                QQC2.Label {
                    id: letter
                    text: TunerController.referenceLetter
                    font.pixelSize: Kirigami.Units.gridUnit * 1.6
                    font.weight: Font.Light
                }
                QQC2.Label {
                    text: TunerController.referenceOctave
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                    anchors.baseline: letter.baseline
                }
            }
            QQC2.Label {
                text: i18nc("frequency", "%1 Hz", TunerController.referenceFrequency.toFixed(2))
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                font.features: { "tnum": 1 }
                color: Kirigami.Theme.disabledTextColor
            }
        }

        QQC2.ToolButton {
            icon.name: "go-next"
            text: i18nc("@action:button", "Semitone up")
            display: QQC2.AbstractButton.IconOnly
            onClicked: TunerController.shiftReference(1)
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 0
        uniformCellSizes: true

        QQC2.ButtonGroup {
            id: timbreGroup
        }
        Repeater {
            model: [
                { timbre: TunerController.Pluck, label: i18nc("@action:button sound type", "Pluck") },
                { timbre: TunerController.Sine, label: i18nc("@action:button sound type", "Sine") },
                { timbre: TunerController.Organ, label: i18nc("@action:button sound type", "Organ") }
            ]
            delegate: QQC2.ToolButton {
                required property var modelData
                Layout.fillWidth: true
                text: modelData.label
                checkable: true
                checked: TunerController.timbre === modelData.timbre
                QQC2.ButtonGroup.group: timbreGroup
                onClicked: TunerController.timbre = modelData.timbre
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing
        Kirigami.Icon {
            source: "audio-volume-medium"
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
        }
        QQC2.Slider {
            Layout.fillWidth: true
            from: 0
            to: 100
            value: TunerController.volume
            onMoved: TunerController.volume = value
            Accessible.name: i18nc("@label:slider", "Volume")
        }
        QQC2.Label {
            Layout.minimumWidth: Kirigami.Units.gridUnit * 2
            horizontalAlignment: Text.AlignRight
            text: i18nc("percent", "%1%", TunerController.volume)
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
        }
    }

    QQC2.CheckBox {
        visible: !TunerController.chromatic
        text: i18nc("@option:check", "Cycle through all strings")
        checked: TunerController.cycleStrings
        onToggled: TunerController.cycleStrings = checked
    }
}
