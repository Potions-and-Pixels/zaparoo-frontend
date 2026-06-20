// Zaparoo Frontend
// Copyright (c) 2026 Wizzo Pty Ltd and the Zaparoo Project contributors.
// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0
pragma ComponentBehavior: Bound

import QtQuick
import Zaparoo.Theme
import Zaparoo.Ui

// Credits menu — top-level entry under the Hub's "Credits" tile.
// Five navigable rows, each routing to a dedicated scrollable
// screen:
//
//   1. "Sponsors"          → SponsorsScreen — dynamic, per-sponsor folders
//   2. "Dev Team"          → DevTeamScreen — static ArtCade dev attribution
//   3. "Artists"           → ArtistsScreen — dynamic, per-artist folders
//   4. "Potions & Pixels"  → PotionsPixelsScreen — static client mission
//   5. "About/License"     → AboutScreen — Zaparoo dev attribution + license
//
// Pure input dispatcher: emits `requestAccept(actionId)` with the
// row's id on Accept, `requestHubScreen()` on Cancel.
Item {
    id: credits

    Component.onCompleted: console.debug("startup/qml component CreditsScreen completed")

    property bool transitioning: false

    signal requestHubScreen
    signal requestAccept(action: string)

    // Single source of truth for the menu rows. Adding a row here is
    // sufficient — focus bounds + Accept routing both derive from
    // `_menu.length` and the row's `action` field, no extra changes
    // needed. Order in this list is the display order.
    readonly property var _menu: [
        { label: qsTr("Sponsors"), action: "sponsors" },
        { label: qsTr("Dev Team"), action: "devTeam" },
        { label: qsTr("Artists"), action: "artists" },
        { label: qsTr("Potions & Pixels"), action: "potionsPixels" },
        { label: qsTr("About/License"), action: "aboutLicense" }
    ]

    property int focusIndex: 0

    function handleAction(action: string): void {
        if (action === "up")
            credits.focusIndex = Math.max(0, credits.focusIndex - 1);
        else if (action === "down")
            credits.focusIndex = Math.min(credits._menu.length - 1, credits.focusIndex + 1);
        else if (action === "accept")
            credits.requestAccept(credits._menu[credits.focusIndex].action);
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
        // Match the rest of the Credits stack for visual continuity.
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
            anchors.topMargin: Sizing.pctH(3)
            anchors.bottomMargin: Sizing.pctH(3)
            spacing: Sizing.pctH(1.5)

            Repeater {
                id: menuRepeater
                model: credits._menu

                Rectangle {
                    id: menuRow

                    required property int index
                    required property var modelData

                    width: body.width
                    height: Sizing.pctH(7)
                    color: Theme.surfaceCard
                    radius: Sizing.cornerRadius
                    border.color: credits.focusIndex === menuRow.index ? Theme.accent : Theme.borderMid
                    border.width: credits.focusIndex === menuRow.index ? Sizing.stroke(2) : Sizing.stroke(1)

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: Sizing.pctW(2)
                        anchors.rightMargin: Sizing.pctW(2)
                        spacing: Sizing.pctW(2)

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: menuRow.modelData.label
                            color: Theme.textPrimary
                            font.family: Theme.fontUi
                            font.pixelSize: Sizing.fontSize(2.8)
                            renderType: Text.NativeRendering
                            width: menuRow.width - Sizing.pctW(8)
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
}
