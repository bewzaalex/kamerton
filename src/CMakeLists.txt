add_executable(kamerton)

target_sources(kamerton PRIVATE
    main.cpp
    audioengine.cpp audioengine.h
    pitchdetector.cpp pitchdetector.h
    tonegenerator.cpp tonegenerator.h
    instruments.cpp instruments.h
    tunercontroller.cpp tunercontroller.h
)

set_source_files_properties(../data/icons/io.github.bewzaalex.kamerton.svg PROPERTIES QT_RESOURCE_ALIAS icons/io.github.bewzaalex.kamerton.svg)

qt_add_qml_module(kamerton
    URI io.github.bewzaalex.kamerton
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/TunerPage.qml
        qml/NeedleGauge.qml
        qml/StrobeDisplay.qml
        qml/BarDisplay.qml
        qml/Headstock.qml
        qml/StringChips.qml
        qml/NoteReadout.qml
        qml/NoiseGateMeter.qml
        qml/StringButton.qml
        qml/ReferencePanel.qml
        qml/SettingsPage.qml
        qml/TuningsPage.qml
    RESOURCES
        ../data/icons/io.github.bewzaalex.kamerton.svg
)

target_include_directories(kamerton PRIVATE ${CMAKE_CURRENT_BINARY_DIR})

target_link_libraries(kamerton PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Widgets
    KF6::CoreAddons
    KF6::ConfigCore
    KF6::I18n
    KF6::I18nQml
    KF6::IconThemes
    PkgConfig::PipeWire
    PkgConfig::FFTW3F
)

install(TARGETS kamerton ${KDE_INSTALL_TARGETS_DEFAULT_ARGS})
