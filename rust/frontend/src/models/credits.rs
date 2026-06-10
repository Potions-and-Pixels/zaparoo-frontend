// Zaparoo Frontend
// Copyright (c) 2026 Wizzo Pty Ltd and the Zaparoo Project contributors.
// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0
//
// `Browse.Credits` — sponsor list surfaced to QML for the Credits
// screen. Index-aligned `QStringList`s (names, logo paths, blurbs)
// rather than a custom `QAbstractListModel`: there are never more
// than a handful of sponsors and the list is fixed at `Initialize`
// time, so the cost of a real model would all be ceremony.
//
// READ + CONSTANT — sponsor data is read once from disk at startup
// and never mutated from QML. Operators editing the credits dir on
// the cabinet (or the Phase-2 agent updating it from CMS) take
// effect on the next frontend launch. Same lifecycle as
// `Browse.BuildInfo`.
//
// The on-disk format (per-sponsor folders with `metadata.toml` +
// `logo.png`) is documented in `zaparoo_core::credits`. The frontend
// just reads what's there.

use cxx_qt::CxxQtType;
use cxx_qt::Initialize;
use cxx_qt_lib::{QString, QStringList};
use std::pin::Pin;
use tracing::info;
use zaparoo_core::credits::load_credits;
use zaparoo_core::platform_paths::credits_dir_path;

#[allow(
    clippy::struct_field_names,
    reason = "the `sponsor_` prefix is intentional — each field is one column of the sibling-list pattern that QML walks by index"
)]
#[derive(Default)]
pub struct CreditsRust {
    sponsor_names: QStringList,
    sponsor_logo_paths: QStringList,
    sponsor_blurbs: QStringList,
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
        // Three index-aligned lists. QML walks them by index in a
        // single `Repeater { model: Browse.Credits.sponsor_names.length; ... }`
        // — see CreditsScreen.qml. READ + CONSTANT + FINAL because the
        // lists are seeded once at Initialize from disk and never
        // mutate; same lifecycle as Browse.BuildInfo's commit/date/channel.
        #[qproperty(QStringList, sponsor_names, READ, CONSTANT, FINAL)]
        #[qproperty(QStringList, sponsor_logo_paths, READ, CONSTANT, FINAL)]
        #[qproperty(QStringList, sponsor_blurbs, READ, CONSTANT, FINAL)]
        type Credits = super::CreditsRust;
    }

    impl cxx_qt::Initialize for Credits {}
}

impl Initialize for ffi::Credits {
    fn initialize(mut self: Pin<&mut Self>) {
        let credits_dir = credits_dir_path();
        // Sponsors use `logo.png` per the long-standing convention.
        let sponsors = load_credits(&credits_dir, "logo.png");

        // Surfaced in /tmp/zaparoo/frontend.log on MiSTer. Lets us
        // diagnose "no sponsors shown" cases by SSH'ing in and
        // grep'ing the log without having to attach to the live
        // frontend or read the qproperty values across the
        // cxx-qt boundary. Includes the absolute dir path so a
        // platform_paths regression is caught at boot.
        info!(
            credits_dir = %credits_dir.display(),
            sponsor_count = sponsors.len(),
            sponsor_slugs = ?sponsors.iter().map(|s| s.folder.as_str()).collect::<Vec<_>>(),
            "Credits model initialized"
        );

        let mut names = QStringList::default();
        let mut logos = QStringList::default();
        let mut blurbs = QStringList::default();

        for sponsor in sponsors {
            names.append(QString::from(sponsor.name.as_str()));
            // QML `Image { source: ... }` accepts a file:// URL or an
            // absolute path. We hand it the absolute path; Qt resolves
            // it automatically. `to_string_lossy` is correct here —
            // FAT32 + ext4 sponsor folder names are ASCII in practice,
            // and the lossy fallback would only matter if an operator
            // dropped a folder with non-UTF-8 bytes (which their host
            // filesystem already rejects on macOS/Linux).
            logos.append(QString::from(sponsor.image_path.to_string_lossy().as_ref()));
            blurbs.append(QString::from(sponsor.blurb.as_str()));
        }

        let mut rust = self.as_mut().rust_mut();
        rust.sponsor_names = names;
        rust.sponsor_logo_paths = logos;
        rust.sponsor_blurbs = blurbs;
    }
}
