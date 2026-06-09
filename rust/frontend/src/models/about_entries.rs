// Zaparoo Frontend
// Copyright (c) 2026 Wizzo Pty Ltd and the Zaparoo Project contributors.
// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0
//
// `Browse.About` — per-section content cards surfaced to QML for
// the Credits → "Potions & Pixels" screen. Each folder under
// `/media/fat/zaparoo/about/` is one scrollable section card
// (title + body prose + optional image). Same loader + on-disk
// schema as `Browse.Credits` / `Browse.Artists` / `Browse.DevTeam`.
//
// Module is `about_entries` (rather than just `about`) because
// `about` is already overloaded in the codebase — `AboutScreen` is
// the upstream Zaparoo About/License screen, which we don't want
// to confuse with this ArtCade-fork section content. The qobject
// the QML side imports is `Browse.About`, which IS the desired
// short name.

use cxx_qt::CxxQtType;
use cxx_qt::Initialize;
use cxx_qt_lib::{QString, QStringList};
use std::pin::Pin;
use tracing::info;
use zaparoo_core::credits::load_credits;
use zaparoo_core::platform_paths::about_dir_path;

#[allow(
    clippy::struct_field_names,
    reason = "the `section_` prefix is intentional — each field is one column of the sibling-list pattern that QML walks by index"
)]
#[derive(Default)]
pub struct AboutRust {
    section_titles: QStringList,
    section_logo_paths: QStringList,
    section_bodies: QStringList,
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
        #[qproperty(QStringList, section_titles, READ, CONSTANT, FINAL)]
        #[qproperty(QStringList, section_logo_paths, READ, CONSTANT, FINAL)]
        #[qproperty(QStringList, section_bodies, READ, CONSTANT, FINAL)]
        type About = super::AboutRust;
    }

    impl cxx_qt::Initialize for About {}
}

impl Initialize for ffi::About {
    fn initialize(mut self: Pin<&mut Self>) {
        let about_dir = about_dir_path();
        // load_credits reused — on-disk schema is identical. The
        // returned `Sponsor::name` maps to the section TITLE here
        // and `Sponsor::blurb` to the section BODY (just a naming
        // difference on the QML side; same underlying data).
        let sections = load_credits(&about_dir);

        info!(
            about_dir = %about_dir.display(),
            section_count = sections.len(),
            section_slugs = ?sections.iter().map(|s| s.folder.as_str()).collect::<Vec<_>>(),
            "About model initialized"
        );

        let mut titles = QStringList::default();
        let mut logos = QStringList::default();
        let mut bodies = QStringList::default();

        for section in sections {
            titles.append(QString::from(section.name.as_str()));
            logos.append(QString::from(section.logo_path.to_string_lossy().as_ref()));
            bodies.append(QString::from(section.blurb.as_str()));
        }

        let mut rust = self.as_mut().rust_mut();
        rust.section_titles = titles;
        rust.section_logo_paths = logos;
        rust.section_bodies = bodies;
    }
}
