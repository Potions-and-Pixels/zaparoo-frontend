// Zaparoo Frontend
// Copyright (c) 2026 Wizzo Pty Ltd and the Zaparoo Project contributors.
// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0
pragma ComponentBehavior: Bound

import QtQuick
import Zaparoo.Theme
import Zaparoo.Ui
import Zaparoo.Browse as Browse

// cxx-qt 0.8 patches `isFinal: true` on singleton properties but the
// qmltypes schema has no `isFinal` slot, so reads of `Browse.Artists`
// fields trip qmllint's "Member can be shadowed" check. Same pattern
// SponsorsScreen uses.
// qmllint disable compiler

// Artists credits screen — reached from Credits → "Artists".
// Same column-stacked card layout as SponsorsScreen: full-width
// portrait/logo on top (PreserveAspectFit), name, blurb. Reads from
// /media/fat/zaparoo/artists/<slug>/ via `Browse.Artists` (cxx-qt
// model reuses the same zaparoo_core::credits::load_credits loader
// the sponsors model uses — same on-disk schema).
Item {
    id: artists

    Component.onCompleted: console.debug("startup/qml component ArtistsScreen completed")

    property bool transitioning: false

    signal requestCreditsScreen

    readonly property bool contentOverflows: body.implicitHeight > flickable.height
    readonly property bool _hasContentAbove: flickable.contentY > 1
    readonly property bool _hasContentBelow: flickable.contentY + flickable.height < flickable.contentHeight - 1

    function _scrollBy(delta: int): void {
        const maxY = Math.max(0, flickable.contentHeight - flickable.height);
        flickable.contentY = Math.max(0, Math.min(maxY, flickable.contentY + delta));
    }

    function handleAction(action: string): void {
        if (action === "up")
            artists._scrollBy(-Sizing.pctH(8));
        else if (action === "down")
            artists._scrollBy(Sizing.pctH(8));
        else if (action === "cancel")
            artists.requestCreditsScreen();
    }

    // ── Visual tree ───────────────────────────────────────────────────────────

    TopStatusStrip {
        id: topStrip
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Sizing.headerBottom
        height: Sizing.pctH(7)
        title: qsTr("Artists")
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
        width: Math.min(parent.width - Sizing.pctW(10), Sizing.pctW(50))
        color: Theme.surfaceCard
        radius: Sizing.cornerRadius
        border.color: Theme.borderMid
        border.width: Sizing.stroke(1)

        Flickable {
            id: flickable

            anchors.fill: parent
            anchors.leftMargin: Sizing.pctW(3)
            anchors.rightMargin: Sizing.pctW(3)
            anchors.topMargin: Sizing.pctH(4)
            anchors.bottomMargin: Sizing.pctH(4)
            contentWidth: width
            contentHeight: body.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: body

                width: parent.width
                spacing: Sizing.pctH(3)

                Item {
                    width: body.width
                    height: Sizing.pctH(1)
                }

                // Empty-list fallback — drops the screen cleanly on
                // installs without an artists/ folder shipped.
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: qsTr("No artists configured.")
                    color: Theme.textLabel
                    font.family: Theme.fontUi
                    font.pixelSize: Sizing.fontSize(2.8)
                    renderType: Text.NativeRendering
                    visible: Browse.Artists.artist_names.length === 0
                }

                Repeater {
                    id: artistRepeater
                    model: Browse.Artists.artist_names.length

                    Rectangle {
                        id: artistCard

                        required property int index

                        width: body.width
                        height: artistColumn.implicitHeight + Sizing.pctH(3) * 2
                        color: Theme.surfaceCard
                        radius: Sizing.cornerRadius
                        border.color: Theme.borderMid
                        border.width: Sizing.stroke(1)

                        Column {
                            id: artistColumn

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.leftMargin: Sizing.pctW(3)
                            anchors.rightMargin: Sizing.pctW(3)
                            anchors.topMargin: Sizing.pctH(3)
                            spacing: Sizing.pctH(1.5)

                            Item {
                                width: parent.width
                                height: Sizing.pctH(20)

                                Image {
                                    anchors.centerIn: parent
                                    width: parent.width
                                    height: parent.height
                                    source: Browse.Artists.artist_logo_paths[artistCard.index]
                                            ? "file://" + Browse.Artists.artist_logo_paths[artistCard.index]
                                            : ""
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    cache: true
                                }
                            }

                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: Browse.Artists.artist_names[artistCard.index]
                                color: Theme.textPrimary
                                font.family: Theme.fontUi
                                font.pixelSize: Sizing.fontSize(3.2)
                                font.weight: Font.Medium
                                renderType: Text.NativeRendering
                                wrapMode: Text.WordWrap
                            }

                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: Browse.Artists.artist_blurbs[artistCard.index]
                                color: Theme.textLabel
                                font.family: Theme.fontUi
                                font.pixelSize: Sizing.fontSize(2.4)
                                renderType: Text.NativeRendering
                                wrapMode: Text.WordWrap
                                visible: text.length > 0
                            }
                        }
                    }
                }

                Item {
                    width: body.width
                    height: Sizing.pctH(1)
                }
            }
        }
    }

    // Scroll chevrons.
    Text {
        anchors.horizontalCenter: card.horizontalCenter
        anchors.top: card.top
        anchors.topMargin: Sizing.pctH(1)
        text: "▲"
        color: Theme.textLabel
        font.family: Theme.fontUi
        font.pixelSize: Sizing.fontSize(2.5)
        renderType: Text.NativeRendering
        visible: artists.contentOverflows && artists._hasContentAbove
    }

    Text {
        anchors.horizontalCenter: card.horizontalCenter
        anchors.bottom: card.bottom
        anchors.bottomMargin: Sizing.pctH(1)
        text: "▼"
        color: Theme.textLabel
        font.family: Theme.fontUi
        font.pixelSize: Sizing.fontSize(2.5)
        renderType: Text.NativeRendering
        visible: artists.contentOverflows && artists._hasContentBelow
    }
}
