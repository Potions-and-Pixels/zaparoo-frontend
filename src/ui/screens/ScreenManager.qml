// Zaparoo Frontend
// Copyright (c) 2026 Wizzo Pty Ltd and the Zaparoo Project contributors.
// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0

pragma Singleton

import QtQuick

// App-wide screen + modal routing. Screens are identified by plain strings
// so a new screen can be added without a central enum; see HubScreen.qml
// and GamesScreen.qml for the current registrants. Modal overlays push
// onto the stack; the top is the one currently receiving input.
QtObject {
    id: manager

    // Screen name constants. Re-exported by MainLayout for test back-compat.
    readonly property string screenHub: "hub"
    readonly property string screenSystems: "systems"
    readonly property string screenGames: "games"
    readonly property string screenFavorites: "favorites"
    readonly property string screenRecents: "recents"
    readonly property string screenUpdate: "update"
    readonly property string screenSettings: "settings"
    readonly property string screenAbout: "about"
    // ArtCade-fork: Credits & Acknowledgements screen reachable directly
    // from the Hub (so the Zaparoo About / License entry stays accessible
    // even on kiosk installs that hide the Settings tile).
    readonly property string screenCredits: "credits"
    // ArtCade-fork: dedicated Sponsors scrollable screen reached from
    // Credits → "Sponsors". Cancel returns to the Credits menu, not
    // the Hub directly.
    readonly property string screenSponsors: "sponsors"
    // ArtCade-fork: three more leaf screens reached from the Credits
    // menu. Same scrollable-card layout as SponsorsScreen.
    //   * Dev Team — static prose, ArtCade engineering acknowledgments
    //   * Artists — dynamic, file-based per-artist folders (mirrors
    //     the sponsors loader, different on-disk dir)
    //   * Potions & Pixels — static prose, client nonprofit mission
    readonly property string screenDevTeam: "devTeam"
    readonly property string screenArtists: "artists"
    readonly property string screenPotionsPixels: "potionsPixels"

    // Currently-focused root screen. Persistence lives in
    // Browse.AppState — write there via Main.qml's orchestration, not
    // here, so we stay decoupled from the persistence layer.
    property string activeScreen: manager.screenHub

    // Modal stack — transient. Top of stack receives input; empty stack
    // means the active root screen handles input.
    property list<string> modalStack: []

    readonly property int modalCount: manager.modalStack.length
    readonly property bool hasModal: manager.modalStack.length > 0
    readonly property string topModal: manager.modalStack.length > 0 ? manager.modalStack[manager.modalStack.length - 1] : ""

    function go(screen: string): void {
        manager.activeScreen = screen;
    }

    function pushModal(name: string): void {
        manager.modalStack = manager.modalStack.concat([name]);
    }

    function popModal(): void {
        if (manager.modalStack.length > 0)
            manager.modalStack = manager.modalStack.slice(0, manager.modalStack.length - 1);
    }
}
