// Zaparoo Frontend
// Copyright (c) 2026 Wizzo Pty Ltd and the Zaparoo Project contributors.
// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0
//
// `Browse.DevTeam` — per-person dev team entries surfaced to QML
// for the Credits → Dev Team screen. Same shape as `Browse.Credits`
// (sponsors) and `Browse.Artists`: reuses the
// `zaparoo_core::credits::load_credits` loader against a different
// dir (`/media/fat/zaparoo/devteam/`).
//
// READ + CONSTANT — same lifecycle as the other credits-stack
// models. Operators editing the devteam dir on the cabinet take
// effect on the next frontend launch.

use cxx_qt::CxxQtType;
use cxx_qt::Initialize;
use cxx_qt_lib::{QString, QStringList};
use std::pin::Pin;
use tracing::info;
use zaparoo_core::credits::load_credits;
use zaparoo_core::platform_paths::dev_team_dir_path;

#[allow(
    clippy::struct_field_names,
    reason = "the `member_` prefix is intentional — each field is one column of the sibling-list pattern that QML walks by index"
)]
#[derive(Default)]
pub struct DevTeamRust {
    member_names: QStringList,
    member_logo_paths: QStringList,
    member_blurbs: QStringList,
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
        #[qproperty(QStringList, member_names, READ, CONSTANT, FINAL)]
        #[qproperty(QStringList, member_logo_paths, READ, CONSTANT, FINAL)]
        #[qproperty(QStringList, member_blurbs, READ, CONSTANT, FINAL)]
        type DevTeam = super::DevTeamRust;
    }

    impl cxx_qt::Initialize for DevTeam {}
}

impl Initialize for ffi::DevTeam {
    fn initialize(mut self: Pin<&mut Self>) {
        let dev_team_dir = dev_team_dir_path();
        // load_credits reused — on-disk schema is identical (slug
        // folder + metadata.toml + logo.png). Returned `Sponsor`
        // entries hold the same name/blurb/logo_path fields the
        // QML side wants.
        let members = load_credits(&dev_team_dir);

        info!(
            dev_team_dir = %dev_team_dir.display(),
            member_count = members.len(),
            member_slugs = ?members.iter().map(|m| m.folder.as_str()).collect::<Vec<_>>(),
            "DevTeam model initialized"
        );

        let mut names = QStringList::default();
        let mut logos = QStringList::default();
        let mut blurbs = QStringList::default();

        for member in members {
            names.append(QString::from(member.name.as_str()));
            logos.append(QString::from(member.logo_path.to_string_lossy().as_ref()));
            blurbs.append(QString::from(member.blurb.as_str()));
        }

        let mut rust = self.as_mut().rust_mut();
        rust.member_names = names;
        rust.member_logo_paths = logos;
        rust.member_blurbs = blurbs;
    }
}
