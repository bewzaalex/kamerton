// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Shapes
import org.kde.kirigami as Kirigami
import io.github.bewzaalex.kamerton

/// Detector, Instrument and Noise gate panels. When the window has room every panel is shown in full;
/// otherwise the Detector stays and the other two shrink to small panels whose button opens the full panel
/// in a popup window, which may reach past the edges of a small tuner window.
Kirigami.Page {
    id: page

    signal settingsRequested()
    signal tuningsRequested()
    signal aboutRequested()

    readonly property bool hasHeadstock: TunerController.headLeft > 0
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

    readonly property string targetText: TunerController.activeString >= 0 && !TunerController.chromatic
        ? i18nc("target frequency, string number", "target %1 Hz · string %2",
                TunerController.targetFrequency.toFixed(2), TunerController.strings[TunerController.activeString]?.number ?? "")
        : i18nc("target frequency", "target %1 Hz", TunerController.targetFrequency.toFixed(2))

    /// "Guitar 6-string · Standard · A4 440 Hz", for the small Instrument panel.
    readonly property string instrumentSummary: [
        [TunerController.instrumentName, TunerController.instrumentVariant].filter(t => t.length > 0).join(" "),
        TunerController.chromatic ? "" : TunerController.tuningName,
        i18nc("concert pitch, %1 is Hz", "A4 %1 Hz", TunerController.a4)
    ].filter(t => t.length > 0).join(" · ")

    // Layout. The meter keeps the golden ratio, so its width tells how much of the window it gets.
    readonly property real goldenRatio: 1.618
    readonly property real gap: Kirigami.Units.largeSpacing
    /// Room a card takes around its content: margins and the border.
    readonly property real cardChrome: Kirigami.Units.largeSpacing * 2 + 2
    readonly property real detectorChrome: detectorHeader.implicitHeight + gap + cardChrome
    readonly property real fullSideWidth: instrumentCard.implicitWidth
    readonly property real fullSideHeight: instrumentCard.implicitHeight + gap + gateCard.implicitHeight
    readonly property real compactSideWidth: Kirigami.Units.gridUnit * 21
    readonly property real compactSideHeight: instrumentStrip.implicitHeight + gap + gateStrip.implicitHeight
    /// The full layout needs at least this meter, and at least 70 % of the meter the compact one would give.
    readonly property real fullMinimumMeter: Kirigami.Units.gridUnit * 26.5
    /// Below this even the compact layout scrolls; the very last resort.
    readonly property real minimumMeter: Kirigami.Units.gridUnit * 14.5
    readonly property var plan: planLayout(flick.width, flick.height)

    title: i18nc("@title", "Tuner")
    globalToolBarStyle: Kirigami.ApplicationHeaderStyle.None
    padding: Kirigami.Units.largeSpacing

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

    /// Height of the compact one-column layout in a window this wide: the smallest the window needs to be.
    function minimumHeightFor(windowWidth) {
        const w = windowWidth - leftPadding - rightPadding;
        return Math.ceil(topPadding + bottomPadding + compactSideHeight + gap + detectorChrome + (w - cardChrome) / goldenRatio);
    }

    /// Full or compact, side column or one column: whichever gives the bigger meter.
    function planLayout(w, h) {
        const meterFor = (cw, ch) => Math.min(cw - cardChrome, (ch - detectorChrome) * goldenRatio);
        const wide = w >= Kirigami.Units.gridUnit * 40;
        const best = (sideWidth, sideHeight) => {
            const side = wide && sideHeight <= h ? meterFor(w - sideWidth - gap, h) : -1;
            const stack = meterFor(w, h - sideHeight - gap);
            return side >= stack ? { side: true, meter: side } : { side: false, meter: stack };
        };
        const full = best(fullSideWidth, fullSideHeight);
        const compact = best(compactSideWidth, compactSideHeight);
        if (full.meter >= fullMinimumMeter && (compact.meter < minimumMeter || full.meter >= 0.7 * compact.meter)) {
            return { full: true, side: full.side, meter: full.meter, scroll: false };
        }
        if (compact.meter >= minimumMeter) {
            return { full: false, side: compact.side, meter: compact.meter, scroll: false };
        }
        return { full: false, side: false, meter: minimumMeter, scroll: true };
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

        Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: page.plan.scroll
            interactive: page.plan.scroll
            boundsBehavior: Flickable.StopAtBounds
            contentWidth: width
            contentHeight: page.plan.scroll ? page.compactSideHeight + page.gap + page.detectorChrome + page.plan.meter / page.goldenRatio : height
            QQC2.ScrollBar.vertical: QQC2.ScrollBar {
                policy: page.plan.scroll ? QQC2.ScrollBar.AsNeeded : QQC2.ScrollBar.AlwaysOff
            }

            GridLayout {
                width: flick.width
                height: flick.contentHeight
                columns: page.plan.side ? 2 : 1
                columnSpacing: page.gap
                rowSpacing: page.gap

                // Instrument and Noise gate: full panels, or small ones that open them in a popup.
                ColumnLayout {
                    Layout.row: page.plan.side ? 0 : 1
                    Layout.column: 0
                    Layout.fillWidth: !page.plan.side
                    Layout.fillHeight: true
                    Layout.preferredWidth: page.plan.side ? (page.plan.full ? page.fullSideWidth : page.compactSideWidth) : -1
                    spacing: page.gap

                    Card {
                        id: instrumentCard
                        visible: page.plan.full
                        Layout.fillWidth: true
                        Layout.fillHeight: page.plan.side
                        implicitWidth: instrumentPanel.implicitWidth + page.cardChrome
                        implicitHeight: instrumentPanel.implicitHeight + page.cardChrome

                        InstrumentPanel {
                            id: instrumentPanel
                            anchors.fill: parent
                            anchors.margins: Kirigami.Units.largeSpacing + 1
                        }
                    }

                    Card {
                        id: gateCard
                        visible: page.plan.full
                        Layout.fillWidth: true
                        implicitHeight: gatePanel.implicitHeight + page.cardChrome

                        NoiseGatePanel {
                            id: gatePanel
                            anchors.fill: parent
                            anchors.margins: Kirigami.Units.largeSpacing + 1
                        }
                    }

                    Card {
                        id: instrumentStrip
                        visible: !page.plan.full
                        Layout.fillWidth: true
                        implicitHeight: instrumentStripContent.implicitHeight + page.cardChrome

                        ColumnLayout {
                            id: instrumentStripContent
                            anchors.fill: parent
                            anchors.margins: Kirigami.Units.largeSpacing + 1
                            spacing: Kirigami.Units.smallSpacing

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Kirigami.Units.smallSpacing

                                PanelButton {
                                    text: i18nc("@title", "Instrument")
                                    open: instrumentFloat.visible
                                    onClicked: instrumentFloat.visible ? instrumentFloat.close() : instrumentFloat.open()

                                    FloatingPanel {
                                        id: instrumentFloat
                                        // A screen too short for the headstock gets the strings as a row instead.
                                        readonly property bool shortScreen: floatingInstrument.headstockHeight + Kirigami.Units.gridUnit * 20 > Screen.desktopAvailableHeight

                                        contentItem: InstrumentPanel {
                                            id: floatingInstrument
                                            readonly property real headstockHeight: Kirigami.Units.gridUnit * 24 * 514 / 522
                                            showHeading: false
                                            stringsAsRow: instrumentFloat.shortScreen
                                        }
                                    }
                                }
                                QQC2.Label {
                                    Layout.fillWidth: true
                                    text: page.instrumentSummary
                                    color: Kirigami.Theme.disabledTextColor
                                    elide: Text.ElideRight
                                }
                                ProgressButton {
                                    visible: !TunerController.chromatic
                                    tuned: TunerController.tunedCount
                                    total: TunerController.strings.length
                                    onClicked: TunerController.resetTuned()
                                }
                            }

                            StringRow {
                                visible: !TunerController.chromatic
                                Layout.fillWidth: true
                            }
                        }
                    }

                    Card {
                        id: gateStrip
                        visible: !page.plan.full
                        Layout.fillWidth: true
                        implicitHeight: gateStripContent.implicitHeight + page.cardChrome

                        RowLayout {
                            id: gateStripContent
                            anchors.fill: parent
                            anchors.margins: Kirigami.Units.largeSpacing + 1
                            spacing: Kirigami.Units.smallSpacing

                            PanelButton {
                                text: i18nc("@title", "Noise gate")
                                open: gateFloat.visible
                                onClicked: gateFloat.visible ? gateFloat.close() : gateFloat.open()

                                FloatingPanel {
                                    id: gateFloat
                                    contentWidth: Kirigami.Units.gridUnit * 22
                                    contentItem: NoiseGatePanel {
                                        showHeading: false
                                    }
                                }
                            }
                            QQC2.Label {
                                text: i18nc("decibels", "%1 dB", String(TunerController.noiseGate).replace("-", "−"))
                                color: Kirigami.Theme.disabledTextColor
                            }
                            MiniLevel {
                                Layout.fillWidth: true
                            }
                        }
                    }

                    Item {
                        visible: !(page.plan.full && page.plan.side)
                        Layout.fillHeight: true
                    }
                }

                // Detector: the display, its style and the main menu
                Card {
                    id: detectorCard
                    Layout.row: 0
                    Layout.column: page.plan.side ? 1 : 0
                    Layout.fillWidth: true
                    Layout.fillHeight: page.plan.side
                    Layout.preferredHeight: page.plan.side ? -1 : page.detectorChrome + page.plan.meter / page.goldenRatio

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.largeSpacing + 1
                        spacing: page.gap

                        RowLayout {
                            id: detectorHeader
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing

                            Kirigami.Heading {
                                level: 4
                                text: i18nc("@title", "Detector")
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                            }
                            SegmentedButtons {
                                accessibleName: i18nc("@label", "Display style")
                                iconsOnly: detectorCard.width < Kirigami.Units.gridUnit * 29
                                value: TunerController.displayStyle
                                model: [
                                    { value: TunerController.Needle, label: i18nc("@action:button display style", "Needle"),
                                      glyph: "M3 17a9 9 0 0 1 18 0M12 17l4-6" },
                                    { value: TunerController.Strobe, label: i18nc("@action:button display style", "Strobe"),
                                      glyph: "M5 5v14M9 5v14M13 5v14M17 5v14M21 5v14" },
                                    { value: TunerController.Bar, label: i18nc("@action:button display style", "Bar"),
                                      glyph: "M4 14v-4M8 15v-6M12 17V7M16 15V9M20 14v-4" }
                                ]
                                onPicked: value => TunerController.displayStyle = value
                            }
                            Kirigami.Separator {
                                Layout.preferredHeight: Kirigami.Units.gridUnit * 1.2
                                Layout.leftMargin: Kirigami.Units.smallSpacing
                                Layout.rightMargin: Kirigami.Units.smallSpacing
                            }
                            MainMenuButton {}
                        }

                        Loader {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            sourceComponent: TunerController.displayStyle === TunerController.Strobe ? strobeComponent
                                           : TunerController.displayStyle === TunerController.Bar ? barComponent
                                           : vuComponent
                        }
                    }
                }
            }
        }
    }

    Component {
        id: vuComponent
        VuMeter {
            cents: TunerController.cents
            active: TunerController.hasSignal
            inTune: TunerController.hasSignal && TunerController.inTune
            noteLetter: TunerController.noteLetter
            noteOctave: TunerController.noteOctave
            frequency: TunerController.frequency
            targetText: page.targetText
        }
    }

    Component {
        id: strobeComponent
        ColumnLayout {
            spacing: Kirigami.Units.largeSpacing
            StrobeDisplay {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: Kirigami.Units.gridUnit * 4
                cents: TunerController.cents
                active: TunerController.hasSignal
                toneColor: page.toneColor
            }
            NoteReadout {
                Layout.alignment: Qt.AlignHCenter
                toneColor: page.toneColor
            }
        }
    }

    Component {
        id: barComponent
        ColumnLayout {
            spacing: Kirigami.Units.largeSpacing
            BarDisplay {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: Kirigami.Units.gridUnit * 4
                cents: TunerController.cents
                active: TunerController.hasSignal
                inTuneZone: TunerController.inTuneThreshold
            }
            NoteReadout {
                Layout.alignment: Qt.AlignHCenter
                toneColor: page.toneColor
            }
        }
    }

    /// Instrument: what is tuned, its strings, auto-detect, A4 and the reference tone.
    /// In a popup the heading is left out, since the small panel's heading and progress stay in view next to it.
    component InstrumentPanel: ColumnLayout {
        id: panel

        property bool showHeading: true
        /// The strings as a row of chips instead of the headstock, for screens too short for it.
        property bool stringsAsRow: false

        spacing: Kirigami.Units.largeSpacing

        RowLayout {
            visible: panel.showHeading
            Layout.fillWidth: true
            Kirigami.Heading {
                level: 4
                text: i18nc("@title", "Instrument")
                Layout.fillWidth: true
            }
            ProgressButton {
                visible: !TunerController.chromatic
                tuned: TunerController.tunedCount
                total: TunerController.strings.length
                onClicked: TunerController.resetTuned()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            uniformCellSizes: !TunerController.chromatic

            DropDownButton {
                id: instrumentButton
                Layout.fillWidth: true
                label: TunerController.instrumentName
                detail: TunerController.instrumentVariant
                down: instrumentPopup.visible
                Accessible.name: i18nc("@action:button", "Instrument: %1", label)
                onClicked: instrumentPopup.visible ? instrumentPopup.close() : instrumentPopup.open()

                InstrumentPopup {
                    id: instrumentPopup
                    y: instrumentButton.height
                    onTuningsRequested: page.tuningsRequested()
                }
            }

            DropDownButton {
                id: tuningButton
                visible: !TunerController.chromatic
                Layout.fillWidth: true
                label: TunerController.tuningName
                down: tuningMenu.visible
                Accessible.name: i18nc("@action:button", "Tuning: %1, %2", TunerController.tuningName, TunerController.tuningNotes)
                onClicked: tuningMenu.visible ? tuningMenu.close() : tuningMenu.popup(tuningButton, 0, tuningButton.height)

                QQC2.Menu {
                    id: tuningMenu
                    // Its own window, so it isn't cut off inside a floating panel.
                    popupType: QQC2.Popup.Window

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
        }

        Headstock {
            visible: page.hasHeadstock && !panel.stringsAsRow
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
            visible: !page.hasHeadstock && !TunerController.chromatic && !panel.stringsAsRow
            Layout.fillWidth: true
            strings: TunerController.strings
            selected: TunerController.selectedString
            playing: page.playingString
            playable: !TunerController.autoDetect
            onPicked: index => page.pickString(index)
        }

        StringRow {
            visible: panel.stringsAsRow && !TunerController.chromatic
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.Switch {
                visible: !TunerController.chromatic
                text: i18nc("@option:check", "Auto-detect string")
                checked: TunerController.autoDetect
                onToggled: TunerController.autoDetect = checked
            }
            Item {
                Layout.fillWidth: true
            }
            QQC2.SpinBox {
                from: 400
                to: 480
                value: TunerController.a4
                editable: true
                textFromValue: (value, locale) => i18nc("concert pitch, %1 is Hz", "A4 %1 Hz", value)
                valueFromText: (text, locale) => parseInt(text.replace(/^\s*A4/i, "").replace(/[^0-9]/g, "")) || 440
                onValueModified: TunerController.a4 = value
                Accessible.name: i18nc("@label:spinbox", "Concert pitch A4")
                QQC2.ToolTip.text: i18nc("@info:tooltip", "Concert pitch: frequency of A4")
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
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

    /// Heading of a small panel: opens the full panel in a popup, and stays highlighted while it is open.
    component PanelButton: QQC2.AbstractButton {
        id: panelButton

        property bool open: false

        hoverEnabled: true
        focusPolicy: Qt.StrongFocus
        leftPadding: Kirigami.Units.largeSpacing
        rightPadding: Kirigami.Units.smallSpacing
        topPadding: Kirigami.Units.smallSpacing
        bottomPadding: Kirigami.Units.smallSpacing
        Layout.leftMargin: -Kirigami.Units.smallSpacing
        Accessible.role: Accessible.ButtonDropDown
        Accessible.name: i18nc("@action:button %1 is a panel name", "Show the %1 panel", text)

        background: Rectangle {
            radius: Kirigami.Units.cornerRadius
            color: panelButton.open ? Qt.alpha(Kirigami.Theme.highlightColor, 0.22)
                 : panelButton.down ? Qt.alpha(Kirigami.Theme.highlightColor, 0.15)
                 : panelButton.hovered ? Qt.alpha(Kirigami.Theme.highlightColor, 0.08)
                 : "transparent"
            border.width: panelButton.open || panelButton.visualFocus ? 1 : 0
            border.color: panelButton.visualFocus ? Kirigami.Theme.focusColor : Kirigami.Theme.highlightColor
        }

        contentItem: RowLayout {
            spacing: Kirigami.Units.smallSpacing
            Kirigami.Heading {
                level: 4
                text: panelButton.text
            }
            Kirigami.Icon {
                source: "arrow-down"
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
            }
        }
    }

    /// A full panel opened from a small one, in a window of its own that may reach past the tuner window,
    /// placed under its button like a menu. A click outside or Esc closes it.
    component FloatingPanel: QQC2.Popup {
        popupType: QQC2.Popup.Window
        x: -Kirigami.Units.smallSpacing
        y: parent.height + Kirigami.Units.smallSpacing
        padding: Kirigami.Units.largeSpacing + 1
        closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutsideParent

        background: Rectangle {
            Kirigami.Theme.colorSet: Kirigami.Theme.View
            Kirigami.Theme.inherit: false
            color: Kirigami.Theme.backgroundColor
            radius: Kirigami.Units.cornerRadius
            border.width: 1
            border.color: Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, Kirigami.Theme.frameContrast)
        }
    }

    /// The strings as a row of small chips, lowest first: in the small Instrument panel, and instead of the
    /// headstock on screens too short for it.
    component StringRow: RowLayout {
        spacing: Kirigami.Units.smallSpacing

        Repeater {
            model: TunerController.strings
            delegate: QQC2.AbstractButton {
                id: chip

                required property var modelData
                required property int index
                readonly property bool selected: index === TunerController.selectedString
                readonly property bool playing: index === page.playingString
                readonly property string noteName: modelData.letter + modelData.octave

                Layout.fillWidth: true
                Layout.preferredWidth: 1
                implicitHeight: Kirigami.Units.gridUnit * 1.8
                hoverEnabled: true
                focusPolicy: Qt.StrongFocus
                onClicked: page.pickString(index)

                Accessible.name: i18nc("@action:button string number, note, frequency", "String %1, %2, %3 Hz",
                                       modelData.number, noteName, Number(modelData.frequency).toFixed(2))
                Accessible.checked: selected
                Accessible.checkable: true
                QQC2.ToolTip.text: i18nc("string number, frequency", "string %1 · %2 Hz", modelData.number, Number(modelData.frequency).toFixed(2))
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay

                background: Rectangle {
                    radius: height / 2
                    color: chip.playing ? Qt.alpha(Kirigami.Theme.highlightColor, 0.4)
                         : chip.selected ? Qt.alpha(Kirigami.Theme.highlightColor, 0.22)
                         : chip.hovered ? Qt.alpha(Kirigami.Theme.highlightColor, 0.08)
                         : "transparent"
                    border.width: chip.selected || chip.visualFocus ? 2 : 1
                    border.color: chip.visualFocus ? Kirigami.Theme.focusColor
                                : chip.selected ? Kirigami.Theme.highlightColor
                                : Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.3)
                }

                contentItem: Item {
                    Row {
                        anchors.centerIn: parent
                        spacing: 1
                        QQC2.Label {
                            id: chipLetter
                            text: chip.modelData.letter
                        }
                        QQC2.Label {
                            text: chip.modelData.octave
                            font.pointSize: chipLetter.font.pointSize * 0.7
                            color: Kirigami.Theme.disabledTextColor
                            anchors.baseline: chipLetter.baseline
                        }
                        // Tuned: the same green badge as on the "x of N tuned" button.
                        Item {
                            visible: chip.modelData.tuned
                            width: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing
                            height: chipLetter.height
                            Rectangle {
                                id: check
                                x: Kirigami.Units.smallSpacing
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - Kirigami.Units.smallSpacing
                                height: width
                                radius: width / 2
                                color: Kirigami.Theme.positiveTextColor
                            }
                            Shape {
                                anchors.fill: check
                                preferredRendererType: Shape.CurveRenderer
                                ShapePath {
                                    scale: Qt.size(check.width / 24, check.height / 24)
                                    fillColor: "transparent"
                                    strokeColor: Kirigami.Theme.highlightedTextColor
                                    strokeWidth: 3.2
                                    capStyle: ShapePath.RoundCap
                                    joinStyle: ShapePath.RoundJoin
                                    PathSvg {
                                        path: "M 6.5 12.5 L 10.5 16.5 L 17.5 8.5"
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    /// Input level and the noise gate in a thin bar, for the small Noise gate panel.
    component MiniLevel: Item {
        readonly property real range: 70
        implicitHeight: 6
        implicitWidth: Kirigami.Units.gridUnit * 4

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.2)
            clip: true

            Rectangle {
                height: parent.height
                radius: parent.radius
                width: parent.width * Math.max(0, Math.min(1, (TunerController.levelDb + parent.parent.range) / parent.parent.range))
                // Same colors as the big meter: grey below the gate, then green, yellow when loud, red near clipping.
                color: TunerController.levelDb <= TunerController.noiseGate ? Kirigami.Theme.disabledTextColor
                     : TunerController.levelDb > -6 ? Kirigami.Theme.negativeTextColor
                     : TunerController.levelDb > -18 ? Kirigami.Theme.neutralTextColor
                     : Kirigami.Theme.positiveTextColor
                Behavior on width {
                    SmoothedAnimation {
                        velocity: 300
                    }
                }
            }
            Rectangle {
                x: parent.width * Math.max(0, Math.min(1, (TunerController.noiseGate + parent.parent.range) / parent.parent.range)) - 1
                width: 2
                height: parent.height
                color: Kirigami.Theme.textColor
            }
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

    /// A button that opens a list: name, an optional muted detail, and an arrow.
    component DropDownButton: QQC2.Button {
        id: dropDown

        /// Shown by the button's own content; `text` stays empty so the style doesn't draw it a second time.
        property string label
        property string detail

        // With an empty `text` the style gives no side padding, so set it here.
        leftPadding: Kirigami.Units.largeSpacing
        rightPadding: Kirigami.Units.largeSpacing

        contentItem: RowLayout {
            spacing: Kirigami.Units.smallSpacing
            QQC2.Label {
                text: dropDown.label
                font.weight: Font.Medium
                elide: Text.ElideRight
                Layout.fillWidth: dropDown.detail.length === 0
            }
            QQC2.Label {
                visible: dropDown.detail.length > 0
                text: dropDown.detail
                color: Kirigami.Theme.disabledTextColor
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Kirigami.Icon {
                source: "arrow-down"
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
            }
        }
    }

    component MainMenuButton: QQC2.ToolButton {
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

    /// "↺ 2 of 6 tuned": shows progress, clicking clears the tuned marks.
    /// When every string is tuned, a check badge takes the reset icon's place until the button is hovered.
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
            color: progress.down ? Qt.alpha(Kirigami.Theme.highlightColor, 0.2)
                 : progress.hovered ? Qt.alpha(Kirigami.Theme.highlightColor, 0.1)
                 : Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.06)
            border.width: progress.visualFocus ? 2 : 1
            border.color: progress.visualFocus ? Kirigami.Theme.highlightColor
                        : Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.25)
        }

        contentItem: Item {
            RowLayout {
                id: progressRow
                anchors.centerIn: parent
                spacing: Kirigami.Units.smallSpacing

                Item {
                    readonly property bool showBadge: progress.complete && !progress.hovered && !progress.visualFocus
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small

                    Kirigami.Icon {
                        anchors.fill: parent
                        visible: !parent.showBadge
                        source: "edit-reset"
                    }
                    Rectangle {
                        anchors.fill: parent
                        visible: parent.showBadge
                        radius: width / 2
                        color: Kirigami.Theme.positiveTextColor
                        Shape {
                            anchors.fill: parent
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                scale: Qt.size(Kirigami.Units.iconSizes.small / 24, Kirigami.Units.iconSizes.small / 24)
                                fillColor: "transparent"
                                strokeColor: Kirigami.Theme.highlightedTextColor
                                strokeWidth: 3.2
                                capStyle: ShapePath.RoundCap
                                joinStyle: ShapePath.RoundJoin
                                PathSvg {
                                    path: "M 6.5 12.5 L 10.5 16.5 L 17.5 8.5"
                                }
                            }
                        }
                    }
                }
                QQC2.Label {
                    text: progress.text
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    font.features: { "tnum": 1 }
                }
            }
        }
    }

    /// Noise gate panel: input level, the draggable gate, and the gate controls under it.
    component NoiseGatePanel: ColumnLayout {
        id: gate

        /// Without the heading (in a popup under the small panel) the level moves onto the meter's top row.
        property bool showHeading: true

        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            visible: gate.showHeading
            Layout.fillWidth: true
            Kirigami.Heading {
                level: 4
                text: i18nc("@title", "Noise gate")
                Layout.fillWidth: true
            }
            QQC2.Label {
                Layout.minimumWidth: levelMetrics.width
                horizontalAlignment: Text.AlignRight
                text: i18nc("input level in decibels", "%1 dB", TunerController.levelDb.toFixed(1).replace("-", "−"))
                font: Kirigami.Theme.smallFont
                color: TunerController.levelDb <= TunerController.noiseGate ? Kirigami.Theme.disabledTextColor : Kirigami.Theme.textColor
                // Wide enough for any level, so the heading doesn't shift while the value changes.
                TextMetrics {
                    id: levelMetrics
                    font: Kirigami.Theme.smallFont
                    text: i18nc("input level in decibels", "%1 dB", "−00.0")
                }
            }
        }

        NoiseGateMeter {
            Layout.fillWidth: true
            leftPadding: 0
            rightPadding: 0
            implicitWidth: Kirigami.Units.gridUnit * 10
            db: TunerController.levelDb
            peak: TunerController.peakDb
            gate: TunerController.noiseGate
            minimumGate: TunerController.minNoiseGate
            maximumGate: TunerController.maxNoiseGate
            defaultGate: TunerController.defaultNoiseGate
            onGateMoved: value => TunerController.noiseGate = value

            QQC2.Label {
                visible: !gate.showHeading
                // On the side away from the gate value, which follows the marker, so the two never overlap.
                x: TunerController.noiseGate > -35 ? parent.leftPadding : parent.width - parent.rightPadding - width
                text: i18nc("input level in decibels", "%1 dB", TunerController.levelDb.toFixed(1).replace("-", "−"))
                font: Kirigami.Theme.smallFont
                color: TunerController.levelDb <= TunerController.noiseGate ? Kirigami.Theme.disabledTextColor : Kirigami.Theme.textColor
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.Button {
                Layout.fillWidth: true
                icon.name: "edit-reset"
                text: i18nc("@action:button reset the noise gate", "Reset")
                enabled: TunerController.noiseGate !== TunerController.defaultNoiseGate
                onClicked: TunerController.noiseGate = TunerController.defaultNoiseGate
                QQC2.ToolTip.text: i18nc("@info:tooltip", "Back to %1 dB", String(TunerController.defaultNoiseGate).replace("-", "−"))
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
            MeasureNoiseButton {
                Layout.fillWidth: true
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
        // Disabled while listening and while it says "Done", so a click can't start it over.
        enabled: !TunerController.measuringNoise && !done
        // As wide as its longest label, so it keeps its size while the label changes.
        implicitWidth: leftPadding + rightPadding + Kirigami.Units.iconSizes.small + spacing
                     + Math.max(idleText.advanceWidth, listeningText.advanceWidth, doneText.advanceWidth)

        TextMetrics {
            id: idleText
            font: measure.font
            text: i18nc("@action:button", "Set from room noise")
        }
        TextMetrics {
            id: listeningText
            font: measure.font
            text: i18nc("@action:button counting down seconds", "Listening… %1 s", 8)
        }
        TextMetrics {
            id: doneText
            font: measure.font
            text: i18nc("@action:button noise gate was set", "Done")
        }

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

    component InstrumentPopup: QQC2.Popup {
        id: popup

        // Its own window, so it isn't cut off inside a floating panel.
        popupType: QQC2.Popup.Window

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
