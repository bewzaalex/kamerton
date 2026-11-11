// SPDX-License-Identifier: GPL-3.0-or-later

#include <QApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQuickStyle>

#include <KAboutData>
#include <KIconTheme>
#include <KLocalizedQmlContext>
#include <KLocalizedString>

#include "kamerton-version.h"

int main(int argc, char *argv[])
{
    KIconTheme::initTheme();
    QApplication app(argc, argv);

    KLocalizedString::setApplicationDomain("kamerton");
    QApplication::setStyle(QStringLiteral("breeze"));
    if (qEnvironmentVariableIsEmpty("QT_QUICK_CONTROLS_STYLE")) {
        QQuickStyle::setStyle(QStringLiteral("org.kde.desktop"));
    }

    KAboutData about(QStringLiteral("kamerton"),
                     i18nc("@title application name", "Kamerton"),
                     QStringLiteral(KAMERTON_VERSION_STRING),
                     i18n("Instrument tuner for guitar, bass, ukulele, violin and more"),
                     KAboutLicense::GPL_V3,
                     i18n("© 2026 Alex Bevza"),
                     QString(),
                     QStringLiteral("https://github.com/bewzaalex/kamerton"));
    about.setLicense(KAboutLicense::GPL_V3, KAboutLicense::OrLaterVersions);
    about.addAuthor(QStringLiteral("Alex Bevza"), i18nc("@info:credit", "Author"));
    about.setBugAddress("https://github.com/bewzaalex/kamerton/issues");
    about.setDesktopFileName(QStringLiteral("io.github.bewzaalex.kamerton"));
    KAboutData::setApplicationData(about);
    QApplication::setWindowIcon(QIcon::fromTheme(QStringLiteral("io.github.bewzaalex.kamerton"), QIcon(QStringLiteral(":/qt/qml/io/github/bewzaalex/kamerton/icons/io.github.bewzaalex.kamerton.svg"))));

    QQmlApplicationEngine engine;
    KLocalization::setupLocalizedContext(&engine);
    engine.loadFromModule("io.github.bewzaalex.kamerton", "Main");
    if (engine.rootObjects().isEmpty()) {
        return -1;
    }
    return app.exec();
}
