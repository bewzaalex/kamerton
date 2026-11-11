// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import io.github.bewzaalex.kamerton

Kirigami.Page {
    id: page

    signal settingsRequested()
    signal tuningsRequested()
    signal aboutRequested()

    readonly property bool hasHeadstock: TunerController.headLeft > 0
    readonly property bool compact: width < Kirigami.Units.gridUnit * 40
    readonly property int playingString: TunerController.playing && !TunerController.chromatic ? TunerController.selectedString : -1

    readonly property color toneColor: {
        if (!TunerController.hasSignal) {
            return Kirigami.Theme.disabledTextColor;
        }
        const c = Math.abs(TunerController.cents);
        if (c <= TunerController.inTuneThreshold) {
            return Kirigami.Theme.positiveTextColor;
        }
        return c <= 15 ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.negativeTextColor;
    }

    title: i18nc("@title", "Tuner")
    globalToolBarStyle: Kirigami.ApplicationHeaderStyle.None
    padding: Kirigami.Units.largeSpacing

    header: QQC2.ToolBar {
        contentItem: RowLayout {
            spacing: Kirigami.Units.smallSpacing

            QQC2.ToolButton {
                id: instrumentButton
                text: TunerController.instrumentVariant.length > 0
                    ? i18nc("instrument and variant", "%1 · %2", TunerController.instrumentName, TunerController.instrumentVariant)
                    : TunerController.instrumentName
                icon.name: "arrow-down"
                LayoutMirroring.enabled: true
                down: instrumentPopup.visible
                onClicked: instrumentPopup.visible ? instrumentPopup.close() : instrumentPopup.open()

                QQC2.ToolTip.text: i18nc("@info:tooltip", "Choose instrument")
                QQC2.ToolTip.visible: hovered && !instrumentPopup.visible
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay

                InstrumentPopup {
                    id: instrumentPopup
                    y: instrumentButton.height
                    onTuningsRequested: page.tuningsRequested()
                }
            }

            QQC2.ToolButton {
                id: tuningButton
                visible: !TunerController.chromatic
                text: page.compact ? TunerController.tuningName
                                   : i18nc("tuning name and notes", "%1  %2", TunerController.tuningName, TunerController.tuningNotes)
                icon.name: "arrow-down"
                LayoutMirroring.enabled: true
                down: tuningMenu.visible
                onClicked: tuningMenu.visible ? tuningMenu.close() : tuningMenu.popup(tuningButton, 0, tuningButton.height)

                QQC2.Menu {
                    id: tuningMenu

                    Instantiator {
                        model: TunerController.tunings
                        delegate: QQC2.MenuItem {
                            required property var modelData
                            required property int index
                            text: i18nc("tuning name and notes", "%1  —  %2", modelData.name, modelData.notes)
                            checkable: true
                            checked: index === TunerController.tuningIndex
                            onTriggered: TunerController.tuningIndex = index
                        }
                        onObjectAdded: (index, object) => tuningMenu.insertItem(index, object)
                        onObjectRemoved: (index, object) => tuningMenu.removeItem(object)
                    }

                    QQC2.MenuSeparator {}

                    QQC2.MenuItem {
                        text: i18nc("@action:inmenu", "Edit Tunings…")
                        icon.name: "document-edit"
                        onTriggered: page.tuningsRequested()
                    }
                }
            }

            Kirigami.Separator {
                Layout.fillHeight: true
                Layout.margins: Kirigami.Units.smallSpacing
            }

            QQC2.SpinBox {
                from: 400
                to: 480
                value: TunerController.a4
                editable: true
                textFromValue: (value, locale) => i18nc("concert pitch, %1 is Hz", "A4 = %1 Hz", value)
                valueFromText: (text, locale) => parseInt(text.replace(/[^0-9]/g, "")) || 440
                onValueModified: TunerController.a4 = value
                Accessible.name: i18nc("@label:spinbox", "Concert pitch A4")
                QQC2.ToolTip.text: i18nc("@info:tooltip", "Concert pitch: frequency of A4")
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
            }

            Item {
                Layout.fillWidth: true
            }

            QQC2.ToolButton {
                id: menuButton
                icon.name: "application-menu"
                display: QQC2.AbstractButton.IconOnly
                text: i18nc("@action:button", "Main Menu")
                down: mainMenu.visible
                onClicked: mainMenu.visible ? mainMenu.close() : mainMenu.popup(menuButton, 0, menuButton.height)
                QQC2.ToolTip.text: text
                QQC2.ToolTip.visible: hovered && !mainMenu.visible
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay

                QQC2.Menu {
                    id: mainMenu
                    QQC2.MenuItem {
                        text: i18nc("@action:inmenu", "Edit Tunings…")
                        icon.name: "document-edit"
                        onTriggered: page.tuningsRequested()
                    }
                    QQC2.MenuItem {
                        text: i18nc("@action:inmenu", "Configure Kamerton…")
                        icon.name: "configure"
                        onTriggered: page.settingsRequested()
                    }
                    QQC2.MenuSeparator {}
                    QQC2.MenuItem {
                        text: i18nc("@action:inmenu", "About Kamerton")
                        icon.name: "help-about"
                        onTriggered: page.aboutRequested()
                    }
                    QQC2.MenuItem {
                        text: i18nc("@action:inmenu", "Quit")
                        icon.name: "application-exit"
                        onTriggered: Qt.quit()
                    }
                }
            }
        }
    }

    /// With auto-detect off, clicking a string plays its reference tone and clicking it again stops it.
    function pickString(index) {
        if (TunerController.autoDetect) {
            TunerController.selectedString = index;
        } else if (TunerController.playing && TunerController.selectedString === index) {
            TunerController.playing = false;
        } else {
            TunerController.selectedString = index;
            TunerController.playing = true;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.largeSpacing

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            type: Kirigami.MessageType.Error
            text: TunerController.audioError
            visible: text.length > 0
            showCloseButton: true
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: page.compact ? 1 : 2
            columnSpacing: Kirigami.Units.largeSpacing
            rowSpacing: Kirigami.Units.largeSpacing

            // Strings, auto-detect and reference tone
            Card {
                Layout.fillHeight: !page.compact
                Layout.fillWidth: page.compact
                Layout.preferredWidth: Math.max(Kirigami.Units.gridUnit * 19, headstock.implicitWidth + Kirigami.Units.largeSpacing * 2 + 2)
                Layout.minimumHeight: sideColumn.implicitHeight + Kirigami.Units.largeSpacing * 2

                ColumnLayout {
                    id: sideColumn
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.largeSpacing
                    spacing: Kirigami.Units.largeSpacing

                    RowLayout {
                        Layout.fillWidth: true
                        Kirigami.Heading {
                            level: 4
                            text: TunerController.chromatic ? i18nc("@title", "Chromatic") : i18nc("@title", "Strings")
                            Layout.fillWidth: true
                        }
                        ProgressButton {
                            visible: !TunerController.chromatic
                            tuned: TunerController.tunedCount
                            total: TunerController.strings.length
                            onClicked: TunerController.resetTuned()
                        }
                    }

                    Headstock {
                        id: headstock
                        visible: page.hasHeadstock
                        Layout.alignment: Qt.AlignHCenter
                        leftCount: TunerController.headLeft
                        rightCount: TunerController.headRight
                        strings: TunerController.strings
                        selected: TunerController.selectedString
                        playing: page.playingString
                        playable: !TunerController.autoDetect
                        onPicked: index => page.pickString(index)
                    }

                    StringChips {
                        visible: !page.hasHeadstock && !TunerController.chromatic
                        Layout.fillWidth: true
                        strings: TunerController.strings
                        selected: TunerController.selectedString
                        playing: page.playingString
                        playable: !TunerController.autoDetect
                        onPicked: index => page.pickString(index)
                    }

                    QQC2.Switch {
                        visible: !TunerController.chromatic
                        Layout.alignment: Qt.AlignHCenter
                        text: i18nc("@option:check", "Auto-detect string")
                        checked: TunerController.autoDetect
                        onToggled: TunerController.autoDetect = checked
                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    Kirigami.Separator {
                        Layout.fillWidth: true
                    }

                    ReferencePanel {
                        Layout.fillWidth: true
                        enabled: TunerController.referenceAvailable
                    }
                }
            }

            // Tuner display
            Card {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: mainColumn.implicitHeight + Kirigami.Units.gridUnit * 2

                ColumnLayout {
                    id: mainColumn
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.gridUnit
                    spacing: Kirigami.Units.largeSpacing

                    Loader {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: Kirigami.Units.gridUnit * 6
                        sourceComponent: TunerController.displayStyle === TunerController.Strobe ? strobeComponent
                                       : TunerController.displayStyle === TunerController.Bar ? barComponent
                                       : needleComponent
                    }

                    NoteReadout {
                        Layout.alignment: Qt.AlignHCenter
                        toneColor: page.toneColor
                    }

                    NoiseGatePanel {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.fillWidth: true
                        Layout.maximumWidth: Kirigami.Units.gridUnit * 32
                    }

                    Kirigami.Separator {
                        Layout.fillWidth: true
                    }

                    DisplayStyleSwitcher {
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }
    }

    Component {
        id: needleComponent
        NeedleGauge {
            cents: TunerController.cents
            active: TunerController.hasSignal
            toneColor: page.toneColor
            inTuneZone: TunerController.inTuneThreshold
        }
    }

    Component {
        id: strobeComponent
        StrobeDisplay {
            cents: TunerController.cents
            active: TunerController.hasSignal
            toneColor: page.toneColor
        }
    }

    Component {
        id: barComponent
        BarDisplay {
            cents: TunerController.cents
            active: TunerController.hasSignal
            inTuneZone: TunerController.inTuneThreshold
        }
    }

    component Card: Rectangle {
        Kirigami.Theme.colorSet: Kirigami.Theme.View
        Kirigami.Theme.inherit: false
        color: Kirigami.Theme.backgroundColor
        radius: Kirigami.Units.cornerRadius
        border.width: 1
        border.color: Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, Kirigami.Theme.frameContrast)
    }

    /// "↺ 2 of 6 tuned": shows progress, clicking clears the tuned marks.
    component ProgressButton: QQC2.AbstractButton {
        id: progress

        property int tuned: 0
        property int total: 0
        readonly property bool complete: total > 0 && tuned === total

        hoverEnabled: true
        focusPolicy: Qt.StrongFocus
        text: i18nc("%1 of %2 strings", "%1 of %2 tuned", tuned, total)
        Accessible.name: i18nc("@action:button", "Start over. %1 of %2 strings tuned", tuned, total)
        implicitHeight: Kirigami.Units.gridUnit * 1.6
        implicitWidth: progressRow.implicitWidth + Kirigami.Units.largeSpacing * 2

        QQC2.ToolTip.text: i18nc("@info:tooltip", "Start over: clear the tuned marks")
        QQC2.ToolTip.visible: hovered
        QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay

        background: Rectangle {
            radius: height / 2
            color: progress.complete ? "transparent"
                 : progress.down ? Qt.alpha(Kirigami.Theme.highlightColor, 0.2)
                 : progress.hovered ? Qt.alpha(Kirigami.Theme.highlightColor, 0.1)
                 : Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.06)
            border.width: progress.visualFocus ? 2 : 1
            border.color: progress.visualFocus ? Kirigami.Theme.highlightColor
                        : progress.complete ? Kirigami.Theme.positiveTextColor
                        : Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.25)
        }

        contentItem: Item {
            RowLayout {
                id: progressRow
                anchors.centerIn: parent
                spacing: Kirigami.Units.smallSpacing
                Kirigami.Icon {
                    source: "edit-reset"
                    color: progress.complete ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.textColor
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                }
                QQC2.Label {
                    text: progress.text
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    font.features: { "tnum": 1 }
                    color: progress.complete ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.textColor
                }
            }
        }
    }

    /// Input level with the draggable noise gate, and the gate controls under it.
    component NoiseGatePanel: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        // Label and current level sit on the meter's line, centred on its track.
        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            QQC2.Label {
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: gateMeter.trackCenter - height / 2
                text: i18nc("@label", "Noise gate adjust")
                font: Kirigami.Theme.smallFont
                color: Kirigami.Theme.disabledTextColor
            }
            NoiseGateMeter {
                id: gateMeter
                Layout.fillWidth: true
                db: TunerController.levelDb
                peak: TunerController.peakDb
                gate: TunerController.noiseGate
                minimumGate: TunerController.minNoiseGate
                maximumGate: TunerController.maxNoiseGate
                defaultGate: TunerController.defaultNoiseGate
                onGateMoved: value => TunerController.noiseGate = value
            }
            QQC2.Label {
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: gateMeter.trackCenter - height / 2
                Layout.minimumWidth: levelMetrics.width
                horizontalAlignment: Text.AlignRight
                text: i18nc("input level in decibels", "%1 dB", TunerController.levelDb.toFixed(1).replace("-", "−"))
                font: Kirigami.Theme.smallFont
                color: TunerController.levelDb <= TunerController.noiseGate ? Kirigami.Theme.disabledTextColor : Kirigami.Theme.textColor
                // Wide enough for any level, so the meter doesn't shift while the value changes.
                TextMetrics {
                    id: levelMetrics
                    font: Kirigami.Theme.smallFont
                    text: i18nc("input level in decibels", "%1 dB", "−00.0")
                }
            }
        }

        // Two buttons of the same width, centred under the meter.
        RowLayout {
            readonly property real buttonWidth: Math.max(Kirigami.Units.gridUnit * 11, resetButton.implicitWidth, measureButton.implicitWidth)

            Layout.alignment: Qt.AlignHCenter
            spacing: Kirigami.Units.smallSpacing

            QQC2.Button {
                id: resetButton
                Layout.preferredWidth: parent.buttonWidth
                icon.name: "edit-reset"
                text: i18nc("@action:button reset the noise gate", "Reset")
                enabled: TunerController.noiseGate !== TunerController.defaultNoiseGate
                onClicked: TunerController.noiseGate = TunerController.defaultNoiseGate
                QQC2.ToolTip.text: i18nc("@info:tooltip", "Back to %1 dB", String(TunerController.defaultNoiseGate).replace("-", "−"))
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
            MeasureNoiseButton {
                id: measureButton
                Layout.preferredWidth: parent.buttonWidth
            }
        }
    }

    /// "Set from room noise": listens for two seconds, then answers with a short "Done" on the button itself.
    component MeasureNoiseButton: QQC2.Button {
        id: measure

        property int secondsLeft: 0
        property bool done: false

        icon.name: done ? "checkmark" : "audio-input-microphone"
        text: TunerController.measuringNoise ? i18nc("@action:button counting down seconds", "Listening… %1 s", secondsLeft)
            : done ? i18nc("@action:button noise gate was set", "Done")
            : i18nc("@action:button", "Set from room noise")
        enabled: !TunerController.measuringNoise

        QQC2.ToolTip.text: i18nc("@info:tooltip", "Keep quiet for two seconds: the noise gate is set just above the noise of the room.")
        QQC2.ToolTip.visible: hovered
        QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay

        onClicked: {
            done = false;
            secondsLeft = Math.round(TunerController.noiseMeasureMs / 1000);
            countdown.start();
            TunerController.measureNoiseGate();
        }

        Timer {
            id: countdown
            interval: 1000
            repeat: true
            onTriggered: measure.secondsLeft = Math.max(1, measure.secondsLeft - 1)
        }
        Timer {
            id: doneTimer
            interval: 1500
            onTriggered: measure.done = false
        }
        Connections {
            target: TunerController
            function onNoiseGateMeasured() {
                countdown.stop();
                measure.done = true;
                doneTimer.restart();
            }
        }
    }

    /// Needle / Strobe / Bar: small equal-width buttons, centered.
    component DisplayStyleSwitcher: Rectangle {
        implicitWidth: styleRow.implicitWidth + 6
        implicitHeight: styleRow.implicitHeight + 6
        radius: Kirigami.Units.cornerRadius + 2
        color: Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.05)

        QQC2.ButtonGroup {
            id: styleGroup
        }

        RowLayout {
            id: styleRow
            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing
            uniformCellSizes: true

            Repeater {
                model: [
                    { style: TunerController.Needle, icon: "speedometer", label: i18nc("@action:button display style", "Needle") },
                    { style: TunerController.Strobe, icon: "view-barcode", label: i18nc("@action:button display style", "Strobe") },
                    { style: TunerController.Bar, icon: "view-media-equalizer", label: i18nc("@action:button display style", "Bar") }
                ]
                delegate: QQC2.ToolButton {
                    required property var modelData
                    Layout.fillWidth: true
                    text: modelData.label
                    icon.name: modelData.icon
                    checkable: true
                    checked: TunerController.displayStyle === modelData.style
                    QQC2.ButtonGroup.group: styleGroup
                    onClicked: TunerController.displayStyle = modelData.style
                }
            }
        }
    }

    component InstrumentPopup: QQC2.Popup {
        id: popup

        signal tuningsRequested()

        padding: Kirigami.Units.smallSpacing
        width: Kirigami.Units.gridUnit * 18
        height: Math.min(list.contentHeight + footerColumn.implicitHeight + topPadding + bottomPadding + Kirigami.Units.smallSpacing,
                         page.height)

        contentItem: ColumnLayout {
            spacing: 0

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: TunerController.instruments
                currentIndex: TunerController.instrumentIndex
                delegate: ColumnLayout {
                    id: entry
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    spacing: 0

                    Kirigami.ListSectionHeader {
                        Layout.fillWidth: true
                        visible: entry.index === 0 || TunerController.instruments[entry.index - 1].group !== entry.modelData.group
                        text: entry.modelData.group
                    }

                    QQC2.ItemDelegate {
                        Layout.fillWidth: true
                        highlighted: entry.index === TunerController.instrumentIndex
                        contentItem: RowLayout {
                            QQC2.Label {
                                text: entry.modelData.name
                            }
                            QQC2.Label {
                                text: entry.modelData.variant
                                color: Kirigami.Theme.disabledTextColor
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            QQC2.Label {
                                visible: entry.modelData.stringCount > 0
                                text: i18ncp("number of strings", "%1 string", "%1 strings", entry.modelData.stringCount)
                                color: Kirigami.Theme.disabledTextColor
                                font: Kirigami.Theme.smallFont
                            }
                        }
                        onClicked: {
                            TunerController.instrumentIndex = entry.index;
                            popup.close();
                        }
                    }
                }
            }

            ColumnLayout {
                id: footerColumn
                Layout.fillWidth: true
                spacing: 0
                Kirigami.Separator {
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    Layout.bottomMargin: Kirigami.Units.smallSpacing
                }
                QQC2.ItemDelegate {
                    Layout.fillWidth: true
                    text: i18nc("@action:button", "Custom Tunings…")
                    icon.name: "list-add"
                    onClicked: {
                        popup.close();
                        popup.tuningsRequested();
                    }
                }
            }
        }
    }
}
