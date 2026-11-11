// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FormCard
import io.github.bewzaalex.kamerton

FormCard.FormCardPage {
    id: page

    title: i18nc("@title:window", "Custom Tunings")

    // Instruments that have strings (the chromatic tuner has none).
    readonly property var stringInstruments: {
        const list = [];
        TunerController.instruments.forEach((inst, index) => {
            if (inst.stringCount > 0) {
                list.push({
                    index: index,
                    label: inst.variant.length > 0 ? i18nc("instrument, variant", "%1 (%2)", inst.name, inst.variant) : inst.name
                });
            }
        });
        return list;
    }

    property string errorText: ""

    FormCard.FormHeader {
        title: i18nc("@title:group", "Your tunings")
    }

    FormCard.FormCard {
        FormCard.FormPlaceholderMessageDelegate {
            visible: TunerController.customTunings.length === 0
            text: i18nc("@info", "No custom tunings yet")
            icon.name: "music-note-16th"
        }

        Repeater {
            model: TunerController.customTunings
            delegate: FormCard.FormTextDelegate {
                required property var modelData
                text: i18nc("tuning name — instrument", "%1 — %2", modelData.name, modelData.instrument)
                description: modelData.notes
                trailing: QQC2.ToolButton {
                    icon.name: "edit-delete"
                    text: i18nc("@action:button", "Delete")
                    display: QQC2.AbstractButton.IconOnly
                    onClicked: TunerController.removeCustomTuning(modelData.instrumentIndex, modelData.tuningIndex)
                    QQC2.ToolTip.text: text
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                }
            }
        }
    }

    FormCard.FormHeader {
        title: i18nc("@title:group", "Add a tuning")
    }

    FormCard.FormCard {
        FormCard.FormComboBoxDelegate {
            id: instrumentCombo
            text: i18nc("@label:listbox", "Instrument")
            model: page.stringInstruments
            textRole: "label"
            valueRole: "index"
            Component.onCompleted: {
                const i = page.stringInstruments.findIndex(e => e.index === TunerController.instrumentIndex);
                currentIndex = i >= 0 ? i : 0;
            }
        }

        FormCard.FormDelegateSeparator {}

        FormCard.FormTextFieldDelegate {
            id: nameField
            label: i18nc("@label:textbox", "Name")
            placeholderText: i18nc("@info:placeholder", "e.g. Open C")
        }

        FormCard.FormDelegateSeparator {}

        FormCard.FormTextFieldDelegate {
            id: notesField
            label: i18nc("@label:textbox", "Notes, lowest string first")
            placeholderText: i18nc("@info:placeholder", "e.g. C2 G2 C3 G3 C4 E4")
            status: Kirigami.MessageType.Error
            statusMessage: text.length > 0 ? TunerController.validateNotes(text) : ""
        }

        FormCard.FormDelegateSeparator {}

        FormCard.FormButtonDelegate {
            text: i18nc("@action:button", "Add Tuning")
            icon.name: "list-add"
            enabled: nameField.text.trim().length > 0 && notesField.text.length > 0 && notesField.statusMessage.length === 0
            onClicked: {
                const error = TunerController.addCustomTuning(instrumentCombo.currentValue, nameField.text, notesField.text);
                page.errorText = error;
                if (error.length === 0) {
                    nameField.text = "";
                    notesField.text = "";
                }
            }
        }
    }

    FormCard.FormSectionText {
        visible: page.errorText.length > 0
        text: page.errorText
    }

    FormCard.FormSectionText {
        text: i18nc("@info", "Write notes with octave numbers: E2 is the low E on a guitar, A4 is the concert pitch A. Use # or b for sharps and flats, for example F#3 or Bb2. New tunings appear in the tuning menu of their instrument.")
    }
}
