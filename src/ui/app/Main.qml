// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0
// SPDX-FileCopyrightText: 2026 Callan Barrett

import QtQuick
import QtQuick.Window
import QtQuick.Controls
import Zaparoo.Ui
import Zaparoo.Theme
import Zaparoo.Browse as Browse

ApplicationWindow {
    id: root

    // Local reference to the singleton — typed property for QML tooling.
    // qmllint disable compiler
    readonly property Browse.BrowseModel browseRef: Browse.BrowseModel
    // qmllint enable compiler

    property bool fullScreen: false

    width: Screen.width
    height: Screen.height
    visible: true
    visibility: fullScreen ? Window.FullScreen : Window.Windowed
    title: "Zaparoo Launcher"

    // Keep Sizing singleton informed of the current resolution.
    onWidthChanged: {
        Sizing.screenWidth = width
        Sizing.screenHeight = height
    }
    onHeightChanged: {
        Sizing.screenHeight = height
        Sizing.screenWidth = width
    }
    Component.onCompleted: {
        Sizing.screenWidth = width
        Sizing.screenHeight = height
    }

    property bool inMenu: false
    property int menuIndex: 0
    property bool crtEnabled: false

    // Slow rainbow hue cycle for the retro aesthetic.
    property real rainbowHue

    NumberAnimation on rainbowHue {
        from: 0
        to: 1
        duration: 12000
        loops: Animation.Infinite
    }

    // Reset carousel to index 0 when root.browseRef loads a new folder.
    Connections {
        target: root.browseRef
        function onModelReset(): void { carousel.currentIndex = 0 }
        function onIndexRestored(newIndex: int): void { carousel.currentIndex = newIndex }
    }

    // ── Background ────────────────────────────────────────────────────────────

    Rectangle {
        anchors.fill: parent
        color: Theme.bgDeep
    }

    Starfield {
        anchors.fill: parent
        z: 0
    }

    // ── FPS counter ───────────────────────────────────────────────────────────

    FpsCounter {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: Sizing.pctH(8)
        anchors.rightMargin: Sizing.pctW(8)
        z: 200
    }

    // ── Title ─────────────────────────────────────────────────────────────────

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Sizing.pctH(3)
        text: "ZAPAROO"
        font.family: Theme.fontRetro
        font.pixelSize: Sizing.fontSize(5)
        color: Qt.hsla(root.rainbowHue, 0.9, 0.65, 1)
    }

    // ── Carousel ──────────────────────────────────────────────────────────────

    // qmllint disable compiler
    Carousel {
        id: carousel

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Sizing.pctH(12)
        width: parent.width
        height: Sizing.pctH(55)
        opacity: root.inMenu ? 0.3 : (root.browseRef.loading ? 0.5 : 1.0)

        browseModel: root.browseRef
        placeholderCover: "qrc:/qt/qml/Zaparoo/App/resources/images/placeholder/cover_generic.png"
        rainbowHue: root.rainbowHue

        onCurrentIndexChanged: root.browseRef.setSelectedIndex(currentIndex)

        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }
    }
    // qmllint enable compiler

    // ── Game title ────────────────────────────────────────────────────────────

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: carousel.bottom
        anchors.topMargin: Sizing.pctH(1)
        // qmllint disable compiler
        text: { root.browseRef.count; return root.browseRef.nameAt(carousel.currentIndex) }
        // qmllint enable compiler
        font.family: Theme.fontRetro
        font.pixelSize: Sizing.fontSize(4)
        color: Theme.textPrimary
        opacity: root.inMenu ? 0.3 : 1.0

        Behavior on opacity {
            NumberAnimation {
                duration: 200
            }
        }
    }

    // ── Selection dots ────────────────────────────────────────────────────────

    SelectionDots {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: carousel.bottom
        anchors.topMargin: Sizing.pctH(8)
        // qmllint disable compiler
        count: root.browseRef.count
        // qmllint enable compiler
        currentIndex: carousel.currentIndex
        rainbowHue: root.rainbowHue
        opacity: root.inMenu ? 0.3 : 1.0

        Behavior on opacity {
            NumberAnimation {
                duration: 200
            }
        }
    }

    // ── Separator ─────────────────────────────────────────────────────────────

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: menuBar.top
        anchors.bottomMargin: Sizing.pctH(1)
        width: Sizing.pctW(60)
        height: 1
        color: Theme.borderFaint
    }

    // ── Menu bar ──────────────────────────────────────────────────────────────

    MenuBar {
        id: menuBar

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: instructionsBar.top
        anchors.bottomMargin: Sizing.pctH(1)
        inMenu: root.inMenu
        menuIndex: root.menuIndex
        rainbowHue: root.rainbowHue
        menuItems: ["PLAY", root.crtEnabled ? "CRT:ON" : "CRT:OFF", "EXIT"]
    }

    // ── Instructions bar ──────────────────────────────────────────────────────

    Rectangle {
        id: instructionsBar

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Sizing.pctH(6)
        color: Theme.bgBar
        border.width: 1
        border.color: Theme.borderSubtle

        Text {
            anchors.centerIn: parent
            // qmllint disable compiler
            text: {
                root.browseRef.count
                const action = root.browseRef.isFolderAt(carousel.currentIndex) ? "OPEN" : "PLAY"
                if (root.inMenu)
                    return "[<>] SEL  [OK] GO  [^] BACK"
                return root.browseRef.canGoBack
                    ? "[<>] BROWSE  [OK] " + action + "  [ESC] BACK  [v] MENU"
                    : "[<>] BROWSE  [OK] " + action + "  [v] MENU"
            }
            // qmllint enable compiler
            font.family: Theme.fontRetro
            font.pixelSize: Sizing.fontSize(2.5)
            color: Theme.textDim
        }
    }

    // ── CRT overlay ───────────────────────────────────────────────────────────

    CrtOverlay {
        anchors.fill: parent
        visible: root.crtEnabled
        z: 100
    }

    // ── Keyboard input ────────────────────────────────────────────────────────

    Item {
        focus: true

        // qmllint disable compiler
        Keys.onPressed: function (event) {
            if (root.inMenu) {
                if (event.key === Qt.Key_Left) {
                    root.menuIndex = (root.menuIndex - 1 + menuBar.menuItems.length) % menuBar.menuItems.length
                } else if (event.key === Qt.Key_Right) {
                    root.menuIndex = (root.menuIndex + 1) % menuBar.menuItems.length
                } else if (event.key === Qt.Key_Up) {
                    root.inMenu = false
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (root.menuIndex === 0) {
                        root.browseRef.launchAt(carousel.currentIndex)
                    } else if (root.menuIndex === 1) {
                        root.crtEnabled = !root.crtEnabled
                    } else if (root.menuIndex === 2) {
                        Qt.quit()
                    }
                } else if (event.key === Qt.Key_Escape) {
                    root.inMenu = false
                }
            } else {
                if (event.key === Qt.Key_Left) {
                    if (carousel.itemCount > 0)
                        carousel.currentIndex = (carousel.currentIndex - 1 + carousel.itemCount) % carousel.itemCount
                } else if (event.key === Qt.Key_Right) {
                    if (carousel.itemCount > 0)
                        carousel.currentIndex = (carousel.currentIndex + 1) % carousel.itemCount
                } else if (event.key === Qt.Key_Down) {
                    root.inMenu = true
                    root.menuIndex = 0
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (root.browseRef.isFolderAt(carousel.currentIndex)) {
                        root.browseRef.enter(carousel.currentIndex)
                    } else {
                        root.browseRef.launchAt(carousel.currentIndex)
                    }
                } else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace) {
                    if (root.browseRef.canGoBack) {
                        root.browseRef.goBack()
                    } else {
                        Qt.quit()
                    }
                }
            }
        }
        // qmllint enable compiler
    }
}
