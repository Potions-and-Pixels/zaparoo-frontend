// Zaparoo Frontend
// Copyright (c) 2026 Wizzo Pty Ltd and the Zaparoo Project contributors.
// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0
pragma Singleton
import QtQuick

// Project-wide color and font constants.
// Never hardcode colors or font families inline — use these instead.
QtObject {
    property bool crtNativePath: false

    // Backgrounds — warm-neutral ramp at H≈36°, S≈4-8%, anchored on the
    // brand color #3D3B38. Replaced the previous lavender-purple field
    // (#0f0f23/#1a1a35/#22223a/#3a3a66 family) deliberately: a tone-on-tone
    // warm-grey backbone in the same hue family as the amber accent lets
    // the focus state be the only saturated color on screen, so each
    // focused tile reads as a single cinematic highlight against a quiet
    // field rather than competing with a colored background.
    readonly property color bgDeep: "#14130F"
    readonly property color bgPanel: "#1F1D19"
    readonly property color bgBar: "#0C0B0A"
    // Card surface used for tile bodies in rows/grids. Sits a step
    // above bgPanel so a solid white icon+label silhouette has clear
    // contrast — the page bg pattern stays visible in the gaps between
    // tiles, and each tile reads as a self-contained chip.
    readonly property color surfaceCard: "#2A2722"
    // Selected row fill — the brand color itself (#3D3B38). At rest the
    // unfocused logos in this row share the exact same tone (see
    // `logoSecondary` below), so the bar reads as a continuous brand
    // band with only the focused tile's amber logo burning through.
    // The accent stripe layered on top remains the per-tile focus cue.
    readonly property color selectionSurface: "#3D3B38"
    // Modal scrim — translucent black so the screen behind a modal
    // dims uniformly without a blur or shader pass.
    readonly property color scrim: "#cc000000"
    // Borders
    readonly property color borderSubtle: "#1A1815"
    readonly property color borderMid: "#5A5650"

    // Text
    readonly property color textPrimary: "#ffffff"
    readonly property color textLabel: "#888888"
    // Variant/disambiguation suffix tone — a muted warm-grey that reads as
    // secondary metadata next to the title without competing with it, and
    // stays legible on `surfaceCard` and on the CRT path. Drawn after the name
    // in the inline caption (see `ScrollingCaption.qml`).
    readonly property color textVariant: "#9A958E"
    // Accent — static honey amber used for selection highlights. Cooled
    // from the original neon orange-amber (#FFB347 → #F2B557): hue nudged
    // ~4° toward yellow, saturation dropped 100→86%. Reads as confident
    // rather than aggressive against the warm-grey field, and sits in
    // the same hue family as the backgrounds so the focus state feels
    // like a saturation/luminance burst rather than a hue jump.
    readonly property color accent: "#F2B557"
    // Persistent-state marker tint (favorite heart, hidden badge). Cool
    // steel-grey at H≈215°, the desaturated complement of the accent,
    // so these markers stay distinct from the focus ring/logo tint
    // instead of melting into them — amber means "selected" exclusively.
    // Saturation is held to ~18% so the marker reads as a quiet
    // secondary cue, not a competing brand color. Paired with a dark
    // `bgBar` outline/border for visibility on light cover art. The
    // hidden badge uses it directly (TileBadge); the favorite heart is
    // tinted to it on the fly via the tinted-svg provider (Heart.svg
    // is a neutral grayscale source), so the color lives only here.
    readonly property color stateMarker: "#8FA0B5"
    // System logo tint tokens — two ramps, selected by Tile based on focus state.
    // Inactive ramp: warm-grey symmetric around the brand anchor
    // (#3D3B38 body at L=23%, +17pt primary highlight, -13pt shadow).
    // Was a lavender-purple ramp (#9898CC/#6060A8/#3C3C80) — the new
    // palette deliberately quiets the unfocused state so the amber
    // focus ramp is the only thing that pops in a dense grid.
    readonly property color logoPrimary: "#6B6862"
    readonly property color logoSecondary: "#3D3B38"
    readonly property color logoShadow: "#1B1916"
    // Focused ramp: honey amber accent marks the selected tile's logo.
    // Hue/saturation tracks the new accent (H≈37°, S≈85%) at three L
    // tiers for the dimensional 3D effect — 86%/64%/32%.
    readonly property color logoFocusPrimary: "#FAE3BD"
    readonly property color logoFocusSecondary: accent
    readonly property color logoFocusShadow: "#8E5A18"
    // Error emphasis, kept distinct from the amber selection accent.
    readonly property string errorHex: "#ff8a7a"
    readonly property color error: errorHex
    // Fonts
    readonly property string fontUi: crtNativePath ? "MxPlus HP 100LX 6x8" : "Noto Sans"
    readonly property string fontMono: crtNativePath ? "MxPlus HP 100LX 6x8" : "monospace"
}
