// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0
// SPDX-FileCopyrightText: 2026 Callan Barrett
//
// Thin C++ entry point for the Rust launcher. Domain logic lives in the
// zaparoo_launcher_rs staticlib; Qt plugin wiring is handled here so that
// Qt's CMake (qt_import_qml_plugins) can emit the correct link flags.

#include <QFile>
#include <QFontDatabase>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QtQml/qqmlextensionplugin.h>

extern "C" int zaparoo_rust_init();
extern "C" void zaparoo_rust_post_qt_start();

// Pull Zaparoo QML plugin symbols into the final binary so the linker does
// not strip their static-initializer registration functions.
Q_IMPORT_QML_PLUGIN(Zaparoo_AppPlugin)
Q_IMPORT_QML_PLUGIN(Zaparoo_UiPlugin)
Q_IMPORT_QML_PLUGIN(Zaparoo_ThemePlugin)
Q_IMPORT_QML_PLUGIN(Zaparoo_BrowsePlugin)

// For static Qt builds (MiSTer ARM32): the QtQuick.Controls plugin chain and
// platform plugin are embedded in the binary, not found on disk, so they
// must be explicitly imported. On dynamic (desktop) Qt these are loaded
// automatically and the symbols don't exist as static functions.
#ifdef QT_STATIC
#include <QtPlugin>
Q_IMPORT_QML_PLUGIN(QtQuickControls2Plugin)
Q_IMPORT_QML_PLUGIN(QtQuickControls2BasicStylePlugin)
Q_IMPORT_QML_PLUGIN(QtQuickControls2ImplPlugin)
Q_IMPORT_QML_PLUGIN(QtQuickTemplates2Plugin)
Q_IMPORT_QML_PLUGIN(QtQuick_WindowPlugin)
Q_IMPORT_PLUGIN(QLinuxFbIntegrationPlugin)
#endif

// NOLINTNEXTLINE(cppcoreguidelines-avoid-non-const-global-variables)
static QFile qtLog;

static void qtMessageHandler(QtMsgType type, const QMessageLogContext& /*ctx*/, const QString& msg)
{
    const char* prefix = nullptr;
    switch (type)
    {
    case QtDebugMsg:
        prefix = "D";
        break;
    case QtInfoMsg:
        prefix = "I";
        break;
    case QtWarningMsg:
        prefix = "W";
        break;
    case QtCriticalMsg:
        prefix = "E";
        break;
    case QtFatalMsg:
        prefix = "F";
        break;
    }
    if (prefix == nullptr)
    {
        return;
    }
    if (qtLog.isOpen())
    {
        qtLog.write(QByteArray(prefix) + " " + msg.toLocal8Bit() + "\n");
        qtLog.flush();
    }
}

int main(int argc, char* argv[])
{
    qtLog.setFileName("/tmp/zaparoo/qt.log");
    (void)qtLog.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text);
    qInstallMessageHandler(qtMessageHandler);

    QGuiApplication::setApplicationName("Zaparoo Launcher");
    QGuiApplication::setApplicationVersion("0.1.0");
    QGuiApplication::setOrganizationName("Zaparoo");
    QGuiApplication::setOrganizationDomain("zaparoo.org");

    if (zaparoo_rust_init() != 0)
    {
        return EXIT_FAILURE;
    }

    QGuiApplication app(argc, argv);
    QFontDatabase::addApplicationFont(":/qt/qml/Zaparoo/App/resources/fonts/PressStart2P.ttf");
    QQuickStyle::setStyle("Basic");

    QQmlApplicationEngine engine;
#ifndef ZAPAROO_DEV_BUILD
    engine.setInitialProperties({{"fullScreen", true}});
#endif
    engine.loadFromModule("Zaparoo.App", "Main");

    if (engine.rootObjects().isEmpty())
    {
        return EXIT_FAILURE;
    }

    zaparoo_rust_post_qt_start();
    return QGuiApplication::exec();
}
