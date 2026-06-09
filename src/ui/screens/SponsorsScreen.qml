// Zaparoo Frontend
// Copyright (c) 2026 Wizzo Pty Ltd and the Zaparoo Project contributors.
// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0
pragma ComponentBehavior: Bound

import QtQuick
import Zaparoo.Theme
import Zaparoo.Ui
import Zaparoo.Browse as Browse

// cxx-qt 0.8 patches `isFinal: true` on singleton properties but the
// qmltypes schema has no `isFinal` slot, so reads of `Browse.Credits`
// fields trip qmllint's "Member can be shadowed" check. Same pattern
// AboutScreen uses for Browse.BuildInfo and CreditsScreen for
// Browse.Credits.
// qmllint disable compiler

// Sponsorship credits screen — reached from Credits → "Sponsors".
// Column-stacked sponsor cards (logo on top, then name, then blurb)
// so logos render at their native aspect ratio instead of being
// squeezed into a fixed-width box. Modeled after AboutScreen's
// scrollable card layout for consistency.
//
// Data source: Browse.Credits's index-aligned QStringLists, populated
// at Initialize time from per-sponsor folders under
// /media/fat/zaparoo/credits/. See rust/zaparoo-core/src/credits.rs
// for the on-disk schema.
//
// Pure input dispatcher: emits `requestCreditsScreen()` on cancel.
// Main.qml does the actual routing.
Item {
    id: sponsors

    Component.onCompleted: console.debug("startup/qml component SponsorsScreen completed")

    // Bound by MainLayout to `root.pendingTransition !== ""`. Sponsors
    // is a destination, never a source — kept for parity with the
    // other screens.
    property bool transitioning: false

    signal requestCreditsScreen

    // True when the body Column overflows the Flickable viewport, so
    // the help bar can show the Up/Down scroll cue only when it's
    // actually meaningful.
    readonly property bool contentOverflows: body.implicitHeight > flickable.height

    // Drive the top/bottom scroll chevrons. 1-px epsilon swallows
    // sub-pixel rounding so the chevrons don't flicker on exact-fit
    // content.
    readonly property bool _hasContentAbove: flickable.contentY > 1
    readonly property bool _hasContentBelow: flickable.contentY + flickable.height < flickable.contentHeight - 1

    function _scrollBy(delta: int): void {
        const maxY = Math.max(0, flickable.contentHeight - flickable.height);
        flickable.contentY = Math.max(0, Math.min(maxY, flickable.contentY + delta));
    }

    function handleAction(action: string): void {
        if (action === "up")
            sponsors._scrollBy(-Sizing.pctH(8));
        else if (action === "down")
            sponsors._scrollBy(Sizing.pctH(8));
        else if (action === "cancel")
            sponsors.requestCreditsScreen();
    // accept and left/right are no-ops on a static page.
    }

    // ── Visual tree ───────────────────────────────────────────────────────────

    TopStatusStrip {
        id: topStrip
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Sizing.headerBottom
        height: Sizing.pctH(7)
        title: qsTr("Sponsors")
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
        // Match AboutScreen's narrower cap — sponsor cards read better
        // at a tighter width with the column-stacked logo+name+blurb,
        // and the cap keeps logos from scaling absurdly large on
        // widescreen.
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

                // Leading spacer — keeps the first sponsor card clear of
                // the top scroll chevron when the page overflows.
                Item {
                    width: body.width
                    height: Sizing.pctH(1)
                }

                // Empty-list fallback — keeps the screen self-explanatory
                // on non-ArtCade installs of the fork (no sponsor folders
                // shipped → no per-sponsor cards → would otherwise look
                // blank). Same visual weight as a sponsor name so it
                // reads as a deliberate message rather than a missing
                // header.
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: qsTr("No sponsors configured.")
                    color: Theme.textLabel
                    font.family: Theme.fontUi
                    font.pixelSize: Sizing.fontSize(2.8)
                    renderType: Text.NativeRendering
                    visible: Browse.Credits.sponsor_names.length === 0
                }

                // Sponsor cards. Column-stacked layout (logo on top,
                // then name, then blurb) so logos display at their
                // native aspect ratio without being squeezed into a
                // fixed-width box. Each card is its own focus-less
                // Rectangle — sponsor data is presentation-only, the
                // cancel button is the only navigable action on this
                // screen.
                Repeater {
                    id: sponsorRepeater
                    model: Browse.Credits.sponsor_names.length

                    Rectangle {
                        id: sponsorCard

                        required property int index

                        width: body.width
                        height: sponsorColumn.implicitHeight + Sizing.pctH(3) * 2
                        color: Theme.surfaceCard
                        radius: Sizing.cornerRadius
                        border.color: Theme.borderMid
                        border.width: Sizing.stroke(1)

                        Column {
                            id: sponsorColumn

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.leftMargin: Sizing.pctW(3)
                            anchors.rightMargin: Sizing.pctW(3)
                            anchors.topMargin: Sizing.pctH(3)
                            spacing: Sizing.pctH(1.5)

                            // Logo — fills the card width, height
                            // bounded by a sane cap so a tall logo
                            // doesn't push the rest off-screen.
                            // PreserveAspectFit keeps the source's
                            // native aspect ratio. Missing logo file
                            // renders as empty (Image.Null status) —
                            // no error, name + blurb still show.
                            Item {
                                width: parent.width
                                height: Sizing.pctH(20)

                                Image {
                                    anchors.centerIn: parent
                                    // Leaves a small margin so a logo
                                    // that's exactly card-width
                                    // doesn't touch the border.
                                    width: parent.width
                                    height: parent.height
                                    source: Browse.Credits.sponsor_logo_paths[sponsorCard.index]
                                            ? "file://" + Browse.Credits.sponsor_logo_paths[sponsorCard.index]
                                            : ""
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    cache: true
                                }
                            }

                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: Browse.Credits.sponsor_names[sponsorCard.index]
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
                                text: Browse.Credits.sponsor_blurbs[sponsorCard.index]
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

                // Trailing spacer — keeps the last sponsor card clear
                // of the bottom scroll chevron when the page overflows.
                Item {
                    width: body.width
                    height: Sizing.pctH(1)
                }
            }
        }
    }

    // Scroll chevrons — same pattern as AboutScreen. Only visible when
    // content overflows; hints shouldn't promise a press that no-ops.
    Text {
        anchors.horizontalCenter: card.horizontalCenter
        anchors.top: card.top
        anchors.topMargin: Sizing.pctH(1)
        text: "▲"
        color: Theme.textLabel
        font.family: Theme.fontUi
        font.pixelSize: Sizing.fontSize(2.5)
        renderType: Text.NativeRendering
        visible: sponsors.contentOverflows && sponsors._hasContentAbove
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
        visible: sponsors.contentOverflows && sponsors._hasContentBelow
    }
}
