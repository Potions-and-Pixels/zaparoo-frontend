// Zaparoo Frontend
// Copyright (c) 2026 Wizzo Pty Ltd and the Zaparoo Project contributors.
// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0
//
// `Browse.Artists` — per-artist contributors surfaced to QML for the
// Artists subscreen of Credits. Same shape as `Browse.Credits`
// (sponsors): index-aligned `QStringList`s populated at `Initialize`
// time from disk. The data shape is literally identical, so we reuse
// the `zaparoo_core::credits::load_credits` loader and just hand it
// a different dir (`/media/fat/zaparoo/artists/`).
//
// READ + CONSTANT — same lifecycle as `Browse.Credits` (and
// `Browse.BuildInfo`). Operators editing the artists dir on the
// cabinet take effect on the next frontend launch.

use cxx_qt::CxxQtType;
use cxx_qt::Initialize;
use cxx_qt_lib::{QString, QStringList};
use std::pin::Pin;
use tracing::info;
use zaparoo_core::credits::load_credits;
use zaparoo_core::platform_paths::artists_dir_path;

#[allow(
    clippy::struct_field_names,
    reason = "the `artist_` prefix is intentional — each field is one column of the sibling-list pattern that QML walks by index"
)]
#[derive(Default)]
pub struct ArtistsRust {
    artist_names: QStringList,
    artist_logo_paths: QStringList,
    artist_blurbs: QStringList,
}

#[cxx_qt::bridge]
pub mod ffi {
    unsafe extern "C++" {
        include!("model_includes.h");

        type QStringList = cxx_qt_lib::QStringList;
    }

    unsafe extern "RustQt" {
        #[qobject]
        #[qml_element]
        #[qml_singleton]
        // Three index-aligned lists — QML walks them by index in a
        // single `Repeater { model: Browse.Artists.artist_names.length; ... }`
        // — see ArtistsScreen.qml. READ + CONSTANT + FINAL because the
        // lists are seeded once at Initialize from disk and never mutate.
        #[qproperty(QStringList, artist_names, READ, CONSTANT, FINAL)]
        #[qproperty(QStringList, artist_logo_paths, READ, CONSTANT, FINAL)]
        #[qproperty(QStringList, artist_blurbs, READ, CONSTANT, FINAL)]
        type Artists = super::ArtistsRust;
    }

    impl cxx_qt::Initialize for Artists {}
}

impl Initialize for ffi::Artists {
    fn initialize(mut self: Pin<&mut Self>) {
        let artists_dir = artists_dir_path();
        // load_credits is intentionally reused — the on-disk schema
        // is identical to the sponsors layout. The returned vec has
        // `folder` / `name` / `blurb` / `logo_path` regardless of
        // whether the source is sponsors or artists.
        let artists = load_credits(&artists_dir);

        info!(
            artists_dir = %artists_dir.display(),
            artist_count = artists.len(),
            artist_slugs = ?artists.iter().map(|a| a.folder.as_str()).collect::<Vec<_>>(),
            "Artists model initialized"
        );

        let mut names = QStringList::default();
        let mut logos = QStringList::default();
        let mut blurbs = QStringList::default();

        for artist in artists {
            names.append(QString::from(artist.name.as_str()));
            // Absolute path; QML `Image { source: ... }` resolves it
            // automatically. `to_string_lossy` is correct here —
            // FAT32 + ext4 artist folder names are ASCII in practice.
            logos.append(QString::from(artist.logo_path.to_string_lossy().as_ref()));
            blurbs.append(QString::from(artist.blurb.as_str()));
        }

        let mut rust = self.as_mut().rust_mut();
        rust.artist_names = names;
        rust.artist_logo_paths = logos;
        rust.artist_blurbs = blurbs;
    }
}
