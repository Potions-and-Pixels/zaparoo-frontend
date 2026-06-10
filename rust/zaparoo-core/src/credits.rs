// Zaparoo Frontend
// Copyright (c) 2026 Wizzo Pty Ltd and the Zaparoo Project contributors.
// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0
//
// Credits loader — generic over Sponsor + Artist + future CreditEntry
// surfaces. Reads per-entry folders from a directory (canonically
// `/media/fat/zaparoo/{credits,artists}/` on a MiSTer cabinet) and
// returns a sorted `Vec<Sponsor>` for the QML side to render. Each
// entry lives in its own folder with a `metadata.toml` and a single
// image file whose filename is configured per-caller:
//
//   - sponsors use `logo.png`
//   - artists use `photo.png`
//
//     credits/
//     ├── acme/
//     │   ├── metadata.toml      # name, blurb, optional display_order
//     │   └── logo.png
//     ├── lowes/
//     │   ├── metadata.toml
//     │   └── logo.png
//     └── ...
//
//     artists/
//     ├── jane-doe/
//     │   ├── metadata.toml
//     │   └── photo.png
//     └── ...
//
// The per-folder layout means adding an entry is "drop a folder" and
// removing is "rm the folder" — no central index file to keep in sync.
// Phase-2 (CMS-managed entries with agent sync) writes the same
// layout, so the frontend code stays identical across phases. The
// struct field is `image_path` rather than `logo_path` so both
// sponsors and artists round-trip cleanly through the same loader.

use serde::Deserialize;
use std::path::{Path, PathBuf};
use tracing::warn;

/// One credit entry read from disk. `image_path` is the absolute path
/// to `<dir>/<folder>/<image_filename>` (i.e. `logo.png` for sponsors,
/// `photo.png` for artists) regardless of whether the file exists —
/// QML's `Image` element will gracefully render nothing for a
/// missing source, which is the right behavior for the
/// metadata-only case.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Sponsor {
    /// Subfolder name (`"acme"`, `"jane-doe"`, etc.). Stable across
    /// syncs; used as the alphabetical-fallback sort key when
    /// `display_order` is missing or tied.
    pub folder: String,
    pub name: String,
    pub blurb: String,
    /// Optional explicit ordering. Lower values come first. `None`
    /// sorts after every `Some(_)` (i.e. unordered entries at the
    /// bottom of the list).
    pub display_order: Option<i64>,
    /// Absolute path to the per-entry image file. The filename is
    /// passed to `load_credits` as the `image_filename` parameter —
    /// `logo.png` for sponsors, `photo.png` for artists.
    pub image_path: PathBuf,
}

#[derive(Deserialize)]
struct RawSponsor {
    name: String,
    blurb: String,
    display_order: Option<i64>,
}

/// Walk `dir`, parse every `<subdir>/metadata.toml`, and return the
/// resulting entries sorted by `display_order` (ascending, `None`
/// last) with alphabetical folder name as the tiebreak.
///
/// `image_filename` is the per-entry image basename to look for
/// (e.g. `"logo.png"` for sponsors, `"photo.png"` for artists).
/// The path is computed as `<dir>/<folder>/<image_filename>`
/// regardless of whether the file actually exists — QML's `Image`
/// renders nothing for a missing source, which is the right default
/// when the operator dropped a metadata-only folder.
///
/// Failure modes are all soft:
/// - Missing `dir` → empty vec. That's the right default for a
///   non-ArtCade install of the fork (no content shipped).
/// - Subdir without a `metadata.toml` → skip silently. Lets operators
///   stash README files, screenshots, etc. in the dir without them
///   being mistaken for entries.
/// - Malformed `metadata.toml` → skip + `warn!`. One bad entry
///   shouldn't blank the whole screen.
///
/// Reading errors (permission denied on the dir, etc.) are also
/// returned as empty + warn. Anything more aggressive would create
/// an unrecoverable startup failure for a screen that's supposed
/// to be informational.
pub fn load_credits(dir: &Path, image_filename: &str) -> Vec<Sponsor> {
    let entries = match std::fs::read_dir(dir) {
        Ok(e) => e,
        Err(err) => {
            if err.kind() != std::io::ErrorKind::NotFound {
                warn!("credit dir read failed at {}: {err}", dir.display());
            }
            return Vec::new();
        }
    };

    let mut sponsors: Vec<Sponsor> = entries
        .filter_map(Result::ok)
        .filter_map(|entry| {
            let path = entry.path();
            if !path.is_dir() {
                return None;
            }
            let folder = entry.file_name().to_string_lossy().into_owned();
            // Skip dotfiles / hidden subdirs — Mac sidecar mounts
            // sometimes leave `.fseventsd`/`.Spotlight-V100`/etc. in
            // FAT32 dirs when operators drop assets via a USB stick.
            if folder.starts_with('.') {
                return None;
            }
            load_entry(&path, folder, image_filename)
        })
        .collect();

    // `None` sorts last so explicitly-ordered sponsors land at the top.
    // Alphabetical folder name breaks ties (stable across syncs).
    sponsors.sort_by(|a, b| {
        let order = match (a.display_order, b.display_order) {
            (Some(a_n), Some(b_n)) => a_n.cmp(&b_n),
            (Some(_), None) => std::cmp::Ordering::Less,
            (None, Some(_)) => std::cmp::Ordering::Greater,
            (None, None) => std::cmp::Ordering::Equal,
        };
        order.then_with(|| a.folder.cmp(&b.folder))
    });

    sponsors
}

fn load_entry(folder_path: &Path, folder: String, image_filename: &str) -> Option<Sponsor> {
    let metadata_path = folder_path.join("metadata.toml");
    let src = match std::fs::read_to_string(&metadata_path) {
        Ok(s) => s,
        Err(err) => {
            // Only `warn!` if the file exists but we can't read it —
            // a subdir with no metadata.toml is the legitimate "this
            // isn't a credit folder" case (README dir, screenshots,
            // operator notes, etc.).
            if err.kind() != std::io::ErrorKind::NotFound {
                warn!("{folder}: could not read metadata.toml ({err})");
            }
            return None;
        }
    };
    let raw: RawSponsor = match toml::from_str(&src) {
        Ok(r) => r,
        Err(err) => {
            warn!("{folder}: malformed metadata.toml — entry skipped ({err})");
            return None;
        }
    };
    let trimmed_name = raw.name.trim();
    if trimmed_name.is_empty() {
        warn!("{folder}: metadata.toml has empty `name` — entry skipped");
        return None;
    }
    Some(Sponsor {
        folder,
        name: trimmed_name.to_string(),
        blurb: raw.blurb.trim().to_string(),
        display_order: raw.display_order,
        image_path: folder_path.join(image_filename),
    })
}

#[cfg(test)]
mod tests {
    #![allow(
        clippy::expect_used,
        clippy::unwrap_used,
        clippy::panic,
        reason = "tests should fail-fast on unexpected errors"
    )]

    use super::*;
    use std::fs;
    use tempfile::TempDir;

    /// Helper: drop a sponsor folder into `root` with the given content.
    fn make_sponsor(root: &Path, folder: &str, toml_body: &str, drop_logo: bool) {
        let dir = root.join(folder);
        fs::create_dir_all(&dir).unwrap();
        fs::write(dir.join("metadata.toml"), toml_body).unwrap();
        if drop_logo {
            fs::write(dir.join("logo.png"), b"\x89PNG-fake-bytes").unwrap();
        }
    }

    #[test]
    fn missing_credits_dir_returns_empty_vec() {
        let tmp = TempDir::new().unwrap();
        let result = load_credits(&tmp.path().join("nonexistent"), "logo.png");
        assert_eq!(result, vec![]);
    }

    #[test]
    fn empty_credits_dir_returns_empty_vec() {
        let tmp = TempDir::new().unwrap();
        let result = load_credits(tmp.path(), "logo.png");
        assert_eq!(result, vec![]);
    }

    /// Happy path: two sponsors with explicit `display_order` render in
    /// the right order, with `logo_path` computed from the folder name.
    #[test]
    fn loads_and_orders_two_sponsors() {
        let tmp = TempDir::new().unwrap();
        make_sponsor(
            tmp.path(),
            "lowes",
            r#"
                name = "Lowe's"
                blurb = "Materials supplier"
                display_order = 2
            "#,
            true,
        );
        make_sponsor(
            tmp.path(),
            "acme",
            r#"
                name = "Acme Foundation"
                blurb = "Founding sponsor"
                display_order = 1
            "#,
            true,
        );
        let result = load_credits(tmp.path(), "logo.png");
        assert_eq!(result.len(), 2);
        assert_eq!(result[0].folder, "acme");
        assert_eq!(result[0].name, "Acme Foundation");
        assert_eq!(result[0].display_order, Some(1));
        assert_eq!(
            result[0].image_path,
            tmp.path().join("acme").join("logo.png")
        );
        assert_eq!(result[1].folder, "lowes");
        assert_eq!(result[1].display_order, Some(2));
    }

    /// Sponsors without `display_order` sort to the bottom in folder
    /// alphabetical order — explicit > unordered. This matches the
    /// expectation that an operator who bothered to specify ordering
    /// wants those sponsors on top.
    #[test]
    fn missing_display_order_sorts_after_explicit() {
        let tmp = TempDir::new().unwrap();
        make_sponsor(tmp.path(), "zeta", "name = \"Zeta\"\nblurb = \"\"\n", false);
        make_sponsor(
            tmp.path(),
            "alpha",
            "name = \"Alpha\"\nblurb = \"\"\n",
            false,
        );
        make_sponsor(
            tmp.path(),
            "ordered",
            "name = \"Ordered\"\nblurb = \"\"\ndisplay_order = 5\n",
            false,
        );
        let result = load_credits(tmp.path(), "logo.png");
        assert_eq!(
            result.iter().map(|s| s.folder.as_str()).collect::<Vec<_>>(),
            vec!["ordered", "alpha", "zeta"],
            "explicit display_order entries come first; unordered entries \
             follow in alphabetical order"
        );
    }

    /// Equal `display_order` falls back to alphabetical folder name —
    /// stable ordering across syncs.
    #[test]
    fn tied_display_order_breaks_alphabetically() {
        let tmp = TempDir::new().unwrap();
        make_sponsor(
            tmp.path(),
            "beta",
            "name = \"Beta\"\nblurb = \"\"\ndisplay_order = 1\n",
            false,
        );
        make_sponsor(
            tmp.path(),
            "alpha",
            "name = \"Alpha\"\nblurb = \"\"\ndisplay_order = 1\n",
            false,
        );
        let result = load_credits(tmp.path(), "logo.png");
        assert_eq!(
            result.iter().map(|s| s.folder.as_str()).collect::<Vec<_>>(),
            vec!["alpha", "beta"]
        );
    }

    /// A subdir without `metadata.toml` is silently skipped — operators
    /// often drop README files or screenshots in the credits dir and
    /// shouldn't see them mistaken for sponsors. No `warn!`,
    /// no Vec entry.
    #[test]
    fn subdir_without_metadata_is_silently_skipped() {
        let tmp = TempDir::new().unwrap();
        fs::create_dir(tmp.path().join("docs")).unwrap();
        fs::write(tmp.path().join("docs").join("README.md"), "notes").unwrap();
        make_sponsor(tmp.path(), "acme", "name = \"Acme\"\nblurb = \"\"\n", true);
        let result = load_credits(tmp.path(), "logo.png");
        assert_eq!(result.len(), 1);
        assert_eq!(result[0].folder, "acme");
    }

    /// A malformed metadata.toml warns + skips the entry. Other valid
    /// sponsors still load.
    #[test]
    fn malformed_metadata_skips_just_that_sponsor() {
        let tmp = TempDir::new().unwrap();
        // Broken TOML — missing closing quote.
        make_sponsor(
            tmp.path(),
            "broken",
            "name = \"never finishes\nblurb = \"x\"\n",
            false,
        );
        make_sponsor(tmp.path(), "good", "name = \"Good\"\nblurb = \"\"\n", false);
        let result = load_credits(tmp.path(), "logo.png");
        assert_eq!(result.len(), 1);
        assert_eq!(result[0].folder, "good");
    }

    /// Empty `name` field is treated as malformed — a sponsor with no
    /// name has nothing to render and is almost certainly an
    /// operator error. Skipped with a warn.
    #[test]
    fn empty_name_is_treated_as_malformed() {
        let tmp = TempDir::new().unwrap();
        make_sponsor(
            tmp.path(),
            "blank",
            "name = \"   \"\nblurb = \"x\"\n",
            false,
        );
        let result = load_credits(tmp.path(), "logo.png");
        assert_eq!(result, vec![]);
    }

    /// Hidden dotfile subdirs (`.fseventsd`, `.Spotlight-V100`,
    /// `._sponsorfolder`) are skipped. macOS sidecar mounts leak
    /// these onto FAT32 partitions when operators drop assets via
    /// a USB stick.
    #[test]
    fn hidden_dotfile_subdirs_are_skipped() {
        let tmp = TempDir::new().unwrap();
        fs::create_dir(tmp.path().join(".fseventsd")).unwrap();
        fs::write(
            tmp.path().join(".fseventsd").join("metadata.toml"),
            "name = \"Should not load\"\nblurb = \"\"\n",
        )
        .unwrap();
        make_sponsor(tmp.path(), "real", "name = \"Real\"\nblurb = \"\"\n", false);
        let result = load_credits(tmp.path(), "logo.png");
        assert_eq!(result.len(), 1);
        assert_eq!(result[0].folder, "real");
    }

    /// Files in the credits dir (not subdirs) are ignored — only
    /// folder children get inspected for `metadata.toml`. Lets the
    /// installer drop a `README.md` at the credits root without it
    /// interfering with parsing.
    #[test]
    fn loose_files_at_credits_root_are_ignored() {
        let tmp = TempDir::new().unwrap();
        fs::write(tmp.path().join("README.md"), "hi").unwrap();
        fs::write(tmp.path().join("notes.txt"), "hi").unwrap();
        make_sponsor(tmp.path(), "acme", "name = \"Acme\"\nblurb = \"\"\n", false);
        let result = load_credits(tmp.path(), "logo.png");
        assert_eq!(result.len(), 1);
    }

    /// `logo_path` is always computed as `<credits>/<folder>/logo.png`
    /// regardless of whether the file actually exists. The QML
    /// `Image` element gracefully renders nothing on a missing
    /// source; the alternative (failing to load the sponsor) would
    /// blank a name + blurb that should still show.
    #[test]
    fn missing_logo_still_loads_sponsor_with_computed_path() {
        let tmp = TempDir::new().unwrap();
        make_sponsor(
            tmp.path(),
            "acme",
            "name = \"Acme\"\nblurb = \"\"\n",
            false, // no logo file
        );
        let result = load_credits(tmp.path(), "logo.png");
        assert_eq!(result.len(), 1);
        assert_eq!(
            result[0].image_path,
            tmp.path().join("acme").join("logo.png")
        );
        assert!(
            !result[0].image_path.exists(),
            "the path is computed even when the file is absent"
        );
    }
}
