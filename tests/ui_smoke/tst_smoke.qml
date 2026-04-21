// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0
// SPDX-FileCopyrightText: 2026 Callan Barrett

import QtQuick
import QtTest
import Zaparoo.App
import Zaparoo.Browse as Browse

TestCase {
    name: "UiSmoke"
    when: windowShown

    Main {
        id: mainWindow
        width: 1280
        height: 720
    }

    function test_window_loads() {
        verify(mainWindow.visible, "Main window should be visible")
        compare(mainWindow.title, "Zaparoo Launcher")
    }

    function test_initial_state() {
        verify(!mainWindow.inMenu, "Should start in carousel mode, not menu mode")
        compare(mainWindow.menuIndex, 0)
        verify(!mainWindow.crtEnabled, "CRT should start off")
    }

    // qmllint disable compiler
    function test_browse_model_initial_state() {
        compare(Browse.BrowseModel.rowCount(), 0)
        compare(Browse.BrowseModel.currentPath, "")
        verify(!Browse.BrowseModel.canGoBack)
    }
    // qmllint enable compiler
}
