// Zaparoo Frontend
// Copyright (c) 2026 Wizzo Pty Ltd and the Zaparoo Project contributors.
// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0
pragma ComponentBehavior: Bound

import QtQuick
import Zaparoo.Theme
import Zaparoo.Ui
import Zaparoo.Browse as Browse

// cxx-qt 0.8 patches `isFinal: true` on singleton properties but the
// qmltypes schema has no `isFinal` slot, so reads of `Browse.About`
// fields trip qmllint's "Member can be shadowed" check.
// qmllint disable compiler

// Potions & Pixels credits screen — reached from Credits →
// "Potions & Pixels". Same column-stacked card layout as the other
// dynamic credits screens. Reads from /media/fat/zaparoo/about/<slug>/
// via `Browse.About` (cxx-qt model reuses the same
// zaparoo_core::credits::load_credits loader). Each folder is one
// section card (title + body + optional image).
Item {
    id: potionsPixels

    Component.onCompleted: console.debug("startup/qml component PotionsPixelsScreen completed")

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
            potionsPixels._scrollBy(-Sizing.pctH(8));
        else if (action === "down")
            potionsPixels._scrollBy(Sizing.pctH(8));
        else if (action === "cancel")
            potionsPixels.requestCreditsScreen();
    }

    TopStatusStrip {
        id: topStrip
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Sizing.headerBottom
        height: Sizing.pctH(7)
        title: qsTr("Potions & Pixels")
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

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: qsTr("No content configured.")
                    color: Theme.textLabel
                    font.family: Theme.fontUi
                    font.pixelSize: Sizing.fontSize(2.8)
                    renderType: Text.NativeRendering
                    visible: Browse.About.section_titles.length === 0
                }

                Repeater {
                    id: sectionRepeater
                    model: Browse.About.section_titles.length

                    Rectangle {
                        id: sectionCard

                        required property int index

                        width: body.width
                        height: sectionColumn.implicitHeight + Sizing.pctH(3) * 2
                        color: Theme.surfaceCard
                        radius: Sizing.cornerRadius
                        border.color: Theme.borderMid
                        border.width: Sizing.stroke(1)

                        Column {
                            id: sectionColumn

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
                                    source: Browse.About.section_logo_paths[sectionCard.index]
                                            ? "file://" + Browse.About.section_logo_paths[sectionCard.index]
                                            : ""
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    cache: true
                                }
                            }

                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: Browse.About.section_titles[sectionCard.index]
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
                                text: Browse.About.section_bodies[sectionCard.index]
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

    Text {
        anchors.horizontalCenter: card.horizontalCenter
        anchors.top: card.top
        anchors.topMargin: Sizing.pctH(1)
        text: "▲"
        color: Theme.textLabel
        font.family: Theme.fontUi
        font.pixelSize: Sizing.fontSize(2.5)
        renderType: Text.NativeRendering
        visible: potionsPixels.contentOverflows && potionsPixels._hasContentAbove
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
        visible: potionsPixels.contentOverflows && potionsPixels._hasContentBelow
    }
}
