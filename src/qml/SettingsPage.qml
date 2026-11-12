// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FormCard
import io.github.bewzaalex.kamerton

FormCard.FormCardPage {
    id: page

    title: i18nc("@title:window", "Configure Kamerton")

    function indexOfDevice(devices, name) {
        for (let i = 0; i < devices.length; ++i) {
            if (devices[i].name === name) {
                return i;
            }
        }
        return 0;
    }

    FormCard.FormHeader {
        title: i18nc("@title:group", "Audio")
    }

    FormCard.FormCard {
        FormCard.FormComboBoxDelegate {
            text: i18nc("@label:listbox", "Microphone / input")
            description: i18nc("@info", "Listens to your instrument.")
            model: TunerController.inputDevices
            textRole: "description"
            valueRole: "name"
            currentIndex: page.indexOfDevice(TunerController.inputDevices, TunerController.inputDevice)
            onActivated: index => TunerController.inputDevice = TunerController.inputDevices[index].name
        }

        FormCard.FormDelegateSeparator {}

        FormCard.FormComboBoxDelegate {
            text: i18nc("@label:listbox", "Speakers / output")
            description: i18nc("@info", "Used to play reference tones.")
            model: TunerController.outputDevices
            textRole: "description"
            valueRole: "name"
            currentIndex: page.indexOfDevice(TunerController.outputDevices, TunerController.outputDevice)
            onActivated: index => TunerController.outputDevice = TunerController.outputDevices[index].name
        }

        FormCard.FormDelegateSeparator {}

        FormCard.FormSpinBoxDelegate {
            label: i18nc("@label:spinbox", "Noise gate")
            description: i18nc("@info", "Sounds quieter than this are ignored. Lower it for a quiet instrument or a distant microphone. You can also drag the marker on the Noise gate adjust meter while tuning.")
            from: TunerController.minNoiseGate
            to: TunerController.maxNoiseGate
            stepSize: 1
            value: TunerController.noiseGate
            textFromValue: (value, locale) => i18nc("decibels", "%1 dB", value)
            valueFromText: (text, locale) => parseInt(text.replace(/[^0-9-]/g, "")) || TunerController.defaultNoiseGate
            onValueChanged: TunerController.noiseGate = value
        }
    }

    FormCard.FormHeader {
        title: i18nc("@title:group", "Tuning")
    }

    FormCard.FormCard {
        FormCard.FormSpinBoxDelegate {
            label: i18nc("@label:spinbox", "Concert pitch (A4)")
            description: i18nc("@info", "440 Hz is standard. Some orchestras use 442 Hz, baroque music 415 Hz.")
            from: 400
            to: 480
            value: TunerController.a4
            textFromValue: (value, locale) => i18nc("frequency", "%1 Hz", value)
            valueFromText: (text, locale) => parseInt(text.replace(/[^0-9]/g, "")) || 440
            onValueChanged: TunerController.a4 = value
        }

        FormCard.FormDelegateSeparator {}

        FormCard.FormSpinBoxDelegate {
            label: i18nc("@label:spinbox", "In-tune tolerance")
            description: i18nc("@info", "How close a string must be to count as tuned.")
            from: 1
            to: 10
            value: Math.round(TunerController.inTuneThreshold)
            textFromValue: (value, locale) => i18nc("cents", "±%1 cents", value)
            valueFromText: (text, locale) => parseInt(text.replace(/[^0-9]/g, "")) || 3
            onValueChanged: TunerController.inTuneThreshold = value
        }

        FormCard.FormDelegateSeparator {}

        FormCard.FormComboBoxDelegate {
            text: i18nc("@label:listbox", "Display")
            model: [
                i18nc("display style", "Needle"),
                i18nc("display style", "Strobe"),
                i18nc("display style", "LED bar")
            ]
            currentIndex: TunerController.displayStyle
            onActivated: index => TunerController.displayStyle = index
        }

        FormCard.FormDelegateSeparator {}

        FormCard.FormButtonDelegate {
            text: i18nc("@action:button", "Custom tunings")
            icon.name: "document-edit"
            onClicked: page.Kirigami.PageStack.pageStack.layers.push(tuningsComponent)
        }
    }

    Component {
        id: tuningsComponent
        TuningsPage {}
    }
}
