// Zaparoo Frontend
// Copyright (c) 2026 Wizzo Pty Ltd and the Zaparoo Project contributors.
// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0
pragma Singleton
import QtQuick

// Project-wide color and font constants.
// Never hardcode colors or font families inline — use these instead.
//
// FORK NOTE (Potions & Pixels / ArtCade):
// Upstream v1.3.1 collapsed this file into a thin proxy over
// `ColorSchemes.palette(id, intensity)` built from a three-color triad
// (primary/accent/text) plus a channel-lerp derivation ladder. The P&P
// palette in this fork is hand-tuned (see the ArtCade installer's
// CHANGELOG 2026/06/29 — warm-neutral H≈36° background field anchored on
// the brand grey #3D3B38, honey-amber accent #F2B557, symmetric logo ramp)
// and does NOT reproduce exactly under the upstream derivations: e.g.
// bgPanel would derive to ~#28241D vs the hand-picked #1F1D19, and
// surfaceCard to ~#302D24 vs the hand-picked #2A2722. Rather than either
// swap in a nearby-but-different look OR fight the derivation with a
// tangle of per-role overrides, this file authors the P&P palette
// directly as an implicit "artcade" preset. Every semantic role the rest
// of the app expects (upstream `selectionFill` / `onAccent` / `marker` /
// `tileEdge` / `controlEdge` / `qrLight` / `qrDark` / `lightSurface`
// asset-selection flag) is declared here with a P&P-tuned value so
// components can read `Theme.<role>` unchanged from upstream call-sites.
//
// If a future rebase adds a real "artcade" entry to ColorSchemes.qml, this
// file can be replaced with the upstream proxy body — the preset id is
// declared as `"artcade"` here on purpose so no call-site would churn.
QtObject {
    // ── CRT / bitmap-font mode flags ────────────────────────────────────────
    // `crtNativePath` gates layout-level slack (BrowseList, PageIndicator,
    // HeaderBar's battery glyph, GamesScreen's portrait fallback, etc.) —
    // it means "we're rendering at the native low-res CRT framebuffer".
    // Upstream introduced a separate `bitmapType` flag for font selection
    // only; keeping both because they aren't the same axis (bitmap font
    // is a font-substitution choice; CRT-native is a whole layout mode).
    property bool crtNativePath: false
    property bool bitmapType: false

    // Preset identity. Fixed here because the palette is authored inline
    // rather than resolved through ColorSchemes.palette(); kept as a
    // property so downstream `Theme.colorSchemeId` reads still resolve.
    // `colorIntensityId` is documented upstream as the accent-bleed level
    // for resting chrome ("subtle" ships everywhere; "vivid" is the
    // opt-in loud path) — P&P was tuned as "subtle", so it stays fixed.
    property string colorSchemeId: "artcade"
    property string colorIntensityId: "subtle"

    readonly property string effectiveColorSchemeId: "artcade"
    // Not a color role — a raster-asset selection flag for cases a color
    // binding cannot express, such as HeaderBar's light/dark logo PNG
    // ladder (Resources.qml -> `logo-on-{dark,light}-*.png`). The P&P
    // palette is a dark-surface preset.
    readonly property bool lightSurface: false

    // ── Backgrounds ─────────────────────────────────────────────────────────
    // Warm-neutral ramp at H≈36°, S≈4-8%, anchored on the brand color
    // #3D3B38. Replaced the previous lavender-purple field
    // (#0f0f23/#1a1a35/#22223a/#3a3a66 family) deliberately: a tone-on-tone
    // warm-grey backbone in the same hue family as the amber accent lets
    // the focus state be the only saturated color on screen, so each
    // focused tile reads as a single cinematic highlight against a quiet
    // field rather than competing with a colored background.
    readonly property color bgDeep: "#14130F"
    readonly property color bgPanel: "#1F1D19"
    readonly property color bgBar: "#0C0B0A"
    // Card surface used for tile bodies in rows/grids. Sits a step above
    // bgPanel so a solid white icon+label silhouette has clear contrast —
    // the page bg pattern stays visible in the gaps between tiles, and
    // each tile reads as a self-contained chip.
    // NOTE (upstream v1.3.1): the previous tiled circuit-trace texture
    // (resources/images/bg-circuit.{png,svg}) was removed upstream; the
    // page background is now painted as a flat `Theme.bgDeep` rectangle
    // in MainLayout.qml. A P&P background pattern, if desired, would
    // need to be re-authored against that flat-fill pipeline.
    readonly property color surfaceCard: "#2A2722"

    // ── Accent-carrying edges (new in upstream v1.3.1) ──────────────────────
    // Resting front-edge strip painted on every tile (PagedGrid) and
    // control (PressableSurface) regardless of focus — a "lit bevel" cue.
    // Warm-amber low-chroma one step up from surfaceCard, low enough that
    // it doesn't compete with the amber focus ring but high enough to
    // hold the raised-surface separation upstream's edge tests assert.
    // Chosen at the P&P palette's own H≈36° hue rather than derived.
    readonly property color tileEdge: "#3F382C"
    readonly property color controlEdge: "#4A4030"

    // ── Selection / on-accent ───────────────────────────────────────────────
    // Fill behind text on a selected row (SelectionBar and anything
    // painting on top of it). The brand grey #3D3B38 itself — at rest,
    // the unfocused logos in this row share the exact same tone (see
    // `logoSecondary` below), so the bar reads as a continuous brand band
    // with only the focused tile's amber logo burning through. Focus
    // rings keep the raw `accent`.
    readonly property color selectionFill: "#3D3B38"
    // Semantic tier — body text/glyphs/control fills sitting on an
    // accent-filled surface, and their subordinate variant. `selectionFill`
    // is dark enough (~7.3:1 vs white) that primary content sits as pure
    // white. `onAccentMuted` is a warm off-white one step down for
    // subordinate on-accent content (tag suffixes, an "off" toggle track
    // on a selected row).
    readonly property color onAccent: textPrimary
    readonly property color onAccentMuted: "#CFC7BE"

    // Modal scrim — translucent black so the screen behind a modal
    // dims uniformly without a blur or shader pass.
    readonly property color scrim: "#cc000000"

    // ── Borders ─────────────────────────────────────────────────────────────
    readonly property color borderSubtle: "#1A1815"
    readonly property color borderMid: "#5A5650"

    // ── Text ────────────────────────────────────────────────────────────────
    readonly property color textPrimary: "#ffffff"
    readonly property color textLabel: "#888888"
    // Variant/disambiguation suffix tone — a muted warm-grey that reads as
    // secondary metadata next to the title without competing with it, and
    // stays legible on `surfaceCard` and on the CRT path. Drawn after the name
    // in the inline caption (see `ScrollingCaption.qml`).
    readonly property color textVariant: "#9A958E"

    // ── Accent ──────────────────────────────────────────────────────────────
    // Static honey amber used for selection highlights. Cooled from the
    // original neon orange-amber (#FFB347 → #F2B557): hue nudged ~4°
    // toward yellow, saturation dropped 100→86%. Reads as confident
    // rather than aggressive against the warm-grey field, and sits in
    // the same hue family as the backgrounds so the focus state feels
    // like a saturation/luminance burst rather than a hue jump.
    readonly property color accent: "#F2B557"

    // ── State markers ───────────────────────────────────────────────────────
    // Persistent-state marker tint (favorite heart, hidden badge). Cool
    // steel-grey at H≈215°, the desaturated complement of the accent, so
    // these markers stay distinct from the focus ring/logo tint instead
    // of melting into them — amber means "selected" exclusively.
    // Saturation is held to ~18% so the marker reads as a quiet
    // secondary cue, not a competing brand color. Paired with a dark
    // outline for visibility on light cover art. The hidden badge uses
    // it directly (TileBadge); the favorite heart is tinted to it on the
    // fly via the tinted-svg provider (Heart.svg is a neutral grayscale
    // source), so the color lives only here. Upstream renamed
    // `stateMarker` → `marker` in v1.3.1.
    readonly property color marker: "#8FA0B5"
    // Marker keyline — a deep cool-grey rim so the marker glyph stays
    // legible on high-luma cover art. Follows the same hue family as
    // `marker` itself so the outline reads as "this marker's rim" rather
    // than a flat black sticker outline.
    readonly property color markerOutline: "#1B2029"

    // ── Logo ramps ──────────────────────────────────────────────────────────
    // Inactive ramp: warm-grey symmetric around the brand anchor
    // (#3D3B38 body at L≈23%, +17pt primary highlight, −13pt shadow).
    // Was a lavender-purple ramp (#9898CC/#6060A8/#3C3C80) — the new
    // palette deliberately quiets the unfocused state so the amber
    // focus ramp is the only thing that pops in a dense grid.
    readonly property color logoPrimary: "#6B6862"
    readonly property color logoSecondary: "#3D3B38"
    readonly property color logoShadow: "#1B1916"
    // Focused ramp: honey amber accent marks the selected tile's logo.
    // Hue/saturation tracks the new accent (H≈37°, S≈85%) at three L
    // tiers for the dimensional 3D effect — 86% / 64% / 32%.
    readonly property color logoFocusPrimary: "#FAE3BD"
    readonly property color logoFocusSecondary: accent
    readonly property color logoFocusShadow: "#8E5A18"

    // ── Error ───────────────────────────────────────────────────────────────
    // Error emphasis, kept distinct from the amber selection accent.
    readonly property string errorHex: "#ff8a7a"
    readonly property color error: errorHex

    // ── QR ──────────────────────────────────────────────────────────────────
    // QR quiet-zone (light) and module (dark) colors — see docs/style.md
    // -> "Themed QR codes". Both ride the accent's own warm hue so the
    // code still reads as themed while measuring well above the 6.0:1
    // contrast floor `test_qr_rungs_stay_scannable` asserts. Authored as
    // literals rather than derived (the OKLCh gamut-fit in ColorSchemes
    // is expensive to run inside a singleton for a single fixed preset).
    readonly property color qrLight: "#FDF6E4"
    readonly property color qrDark: "#5A4014"

    // ── Fonts ───────────────────────────────────────────────────────────────
    // Font selection is upstream's `bitmapType` axis (whether the UI
    // renders in the 6x8 bitmap face). Independent of `crtNativePath` —
    // a CRT render path with a smoothed font is possible.
    readonly property string fontUi: bitmapType ? "MxPlus HP 100LX 6x8" : "Noto Sans"
    readonly property string fontMono: bitmapType ? "MxPlus HP 100LX 6x8" : "monospace"
}
