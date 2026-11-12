// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FormCard
import io.github.bewzaalex.kamerton

Kirigami.ApplicationWindow {
    id: root

    title: i18nc("@title:window", "Kamerton")

    width: Kirigami.Units.gridUnit * 60
    height: Kirigami.Units.gridUnit * 40
    minimumWidth: Kirigami.Units.gridUnit * 24
    // As tall as the compact layout needs at the minimum width, so the smallest window has no empty space.
    minimumHeight: tunerPage.minimumHeightFor(minimumWidth)

    function openSettings(): void {
        if (pageStack.layers.depth === 1) {
            pageStack.layers.push(settingsComponent);
        }
    }

    function openTunings(): void {
        if (pageStack.layers.depth === 1) {
            pageStack.layers.push(tuningsComponent);
        }
    }

    function openAbout(): void {
        if (pageStack.layers.depth === 1) {
            pageStack.layers.push(aboutComponent);
        }
    }

    pageStack.initialPage: TunerPage {
        id: tunerPage
        onSettingsRequested: root.openSettings()
        onTuningsRequested: root.openTunings()
        onAboutRequested: root.openAbout()
    }

    Component {
        id: settingsComponent
        SettingsPage {}
    }

    Component {
        id: tuningsComponent
        TuningsPage {}
    }

    Component {
        id: aboutComponent
        FormCard.AboutPage {}
    }

    Shortcut {
        sequences: [StandardKey.Preferences]
        onActivated: root.openSettings()
    }

    Shortcut {
        sequences: [StandardKey.Quit]
        onActivated: Qt.quit()
    }

    Shortcut {
        sequence: "Space"
        enabled: root.pageStack.layers.depth === 1 && TunerController.referenceAvailable
        onActivated: TunerController.playing = !TunerController.playing
    }
}
