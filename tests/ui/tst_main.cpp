// Zaparoo Launcher
// Copyright (c) 2026 The Zaparoo Project Contributors.
// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0

#include <QtQml/qqmlextensionplugin.h>
#include <QtQuickTest/quicktest.h>

Q_IMPORT_QML_PLUGIN(Zaparoo_AppPlugin)
Q_IMPORT_QML_PLUGIN(Zaparoo_Browse_plugin)
Q_IMPORT_QML_PLUGIN(Zaparoo_UiPlugin)
Q_IMPORT_QML_PLUGIN(Zaparoo_ThemePlugin)

extern "C" int zaparoo_rust_init();

// Initializes the Rust model globals (tokio runtime, client, catalog channel)
// before the QML engine is created. The WebSocket client will fail to connect
// (no server running) and models will be empty — fine for behavioural UI tests
// that don't depend on live catalog data.
class UiSetup : public QObject
{
    Q_OBJECT

  public slots:
    // NOLINTNEXTLINE(readability-convert-member-functions-to-static) — Qt slot, must be a member
    void applicationAvailable()
    {
        zaparoo_rust_init();
    }
};

QUICK_TEST_MAIN_WITH_SETUP(zaparoo_ui, UiSetup)

#include "tst_main.moc"
