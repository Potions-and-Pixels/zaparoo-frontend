// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0
// SPDX-FileCopyrightText: 2026 Callan Barrett

#include <QtQml/qqmlextensionplugin.h>
#include <QtQuickTest/quicktest.h>

Q_IMPORT_QML_PLUGIN(Zaparoo_AppPlugin)
Q_IMPORT_QML_PLUGIN(Zaparoo_Browse_plugin)
Q_IMPORT_QML_PLUGIN(Zaparoo_UiPlugin)
Q_IMPORT_QML_PLUGIN(Zaparoo_ThemePlugin)

extern "C" int zaparoo_rust_init();

// Initializes the Rust model globals (tokio runtime, client, catalog channel)
// before the QML engine is created. The WebSocket client will fail to connect
// (no server running) and models will be empty — fine for a visual smoke test.
class SmokeSetup : public QObject
{
    Q_OBJECT

  public slots:
    void applicationAvailable()
    {
        zaparoo_rust_init();
    }
};

QUICK_TEST_MAIN_WITH_SETUP(zaparoo_ui_smoke, SmokeSetup)

#include "tst_main.moc"
