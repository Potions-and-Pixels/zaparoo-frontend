// Zaparoo Frontend
// Copyright (c) 2026 Wizzo Pty Ltd and the Zaparoo Project contributors.
// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0
pragma ComponentBehavior: Bound

import QtQuick
import Zaparoo.Theme
import Zaparoo.Ui

// Credits menu — top-level entry under the Hub's "Credits" tile.
// Two navigable rows, both routing to dedicated scrollable screens:
//
//   1. "Sponsors" → SponsorsScreen — column-stacked sponsor cards
//      rendered from /media/fat/zaparoo/credits/<slug>/.
//
//   2. "About/License" → AboutScreen — Zaparoo dev attribution +
//      PolyForm license. Reused (with AboutScreen.openedFromCredits
//      set in Main.qml) so cancel returns here instead of Settings.
//
// Pure input dispatcher: emits `requestAccept(actionId)` with the
// row's id ("sponsors" or "aboutLicense") on Accept, and
// `requestHubScreen()` on Cancel. All cross-screen orchestration
// lives in Main.qml.
Item {
    id: credits

    Component.onCompleted: console.debug("startup/qml component CreditsScreen completed")

    // Bound by MainLayout to `root.pendingTransition !== ""`. Credits
    // is a destination, never a source — kept for parity with the
    // other screens.
    property bool transitioning: false

    signal requestHubScreen
    signal requestAccept(action: string)

    // Focus index between the two menu rows. 0 = Sponsors, 1 =
    // About/License. The screen has exactly two navigable items;
    // hardcoding the bound rather than threading a model.length is
    // simpler and matches the actual UI.
    property int focusIndex: 0
    readonly property int _itemCount: 2

    function handleAction(action: string): void {
        if (action === "up")
            credits.focusIndex = Math.max(0, credits.focusIndex - 1);
        else if (action === "down")
            credits.focusIndex = Math.min(credits._itemCount - 1, credits.focusIndex + 1);
        else if (action === "accept")
            credits.requestAccept(credits.focusIndex === 0 ? "sponsors" : "aboutLicense");
        else if (action === "cancel")
            credits.requestHubScreen();
    // left/right are no-ops on a single-column menu.
    }

    // ── Visual tree ───────────────────────────────────────────────────────────

    TopStatusStrip {
        id: topStrip
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Sizing.headerBottom
        height: Sizing.pctH(7)
        title: qsTr("Credits")
        currentPage: 0
        totalPages: 0
        totalText: ""
    }

    Rectangle {
        id: card

        anchors.top: topStrip.bottom
        anchors.topMargin: Sizing.pctH(2)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Sizing.pctH(8)
        anchors.horizontalCenter: parent.horizontalCenter
        // Match AboutScreen / SponsorsScreen's narrow cap for visual
        // continuity across the Credits stack.
        width: Math.min(parent.width - Sizing.pctW(10), Sizing.pctW(50))
        color: Theme.surfaceCard
        radius: Sizing.cornerRadius
        border.color: Theme.borderMid
        border.width: Sizing.stroke(1)

        Column {
            id: body

            anchors.fill: parent
            anchors.leftMargin: Sizing.pctW(3)
            anchors.rightMargin: Sizing.pctW(3)
            anchors.topMargin: Sizing.pctH(4)
            anchors.bottomMargin: Sizing.pctH(4)
            spacing: Sizing.pctH(2)

            // ── "Sponsors" entry ───────────────────────────────────
            Rectangle {
                id: sponsorsEntry

                width: parent.width
                height: Sizing.pctH(8)
                color: Theme.surfaceCard
                radius: Sizing.cornerRadius
                border.color: credits.focusIndex === 0 ? Theme.accent : Theme.borderMid
                border.width: credits.focusIndex === 0 ? Sizing.stroke(2) : Sizing.stroke(1)

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: Sizing.pctW(2)
                    anchors.rightMargin: Sizing.pctW(2)
                    spacing: Sizing.pctW(2)

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Sponsors")
                        color: Theme.textPrimary
                        font.family: Theme.fontUi
                        font.pixelSize: Sizing.fontSize(2.8)
                        renderType: Text.NativeRendering
                        width: sponsorsEntry.width - Sizing.pctW(8)
                        elide: Text.ElideRight
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "›"
                        color: Theme.textLabel
                        font.family: Theme.fontUi
                        font.pixelSize: Sizing.fontSize(4)
                        renderType: Text.NativeRendering
                    }
                }
            }

            // ── "About/License" entry ─────────────────────────────
            Rectangle {
                id: aboutEntry

                width: parent.width
                height: Sizing.pctH(8)
                color: Theme.surfaceCard
                radius: Sizing.cornerRadius
                border.color: credits.focusIndex === 1 ? Theme.accent : Theme.borderMid
                border.width: credits.focusIndex === 1 ? Sizing.stroke(2) : Sizing.stroke(1)

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: Sizing.pctW(2)
                    anchors.rightMargin: Sizing.pctW(2)
                    spacing: Sizing.pctW(2)

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("About/License")
                        color: Theme.textPrimary
                        font.family: Theme.fontUi
                        font.pixelSize: Sizing.fontSize(2.8)
                        renderType: Text.NativeRendering
                        width: aboutEntry.width - Sizing.pctW(8)
                        elide: Text.ElideRight
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "›"
                        color: Theme.textLabel
                        font.family: Theme.fontUi
                        font.pixelSize: Sizing.fontSize(4)
                        renderType: Text.NativeRendering
                    }
                }
            }
        }
    }
}
