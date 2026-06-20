// Zaparoo Frontend
// Copyright (c) 2026 Wizzo Pty Ltd and the Zaparoo Project contributors.
// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0

use crate::runtime;
use std::path::PathBuf;

pub fn config_file_path() -> PathBuf {
    if runtime::current().is_mister() {
        PathBuf::from("/media/fat/zaparoo/frontend.toml")
    } else {
        dirs_next::config_dir()
            .unwrap_or_else(|| PathBuf::from("."))
            .join("zaparoo")
            .join("frontend.toml")
    }
}

pub fn log_file_path() -> PathBuf {
    if runtime::current().is_mister() {
        PathBuf::from("/tmp/zaparoo/frontend.log")
    } else {
        dirs_next::data_local_dir()
            .unwrap_or_else(|| PathBuf::from("."))
            .join("zaparoo")
            .join("logs")
            .join("frontend.log")
    }
}

/// Path to the raw stderr capture file. The frontend dup2's its own
/// `STDERR_FILENO` onto this file early in startup so that the chained
/// default panic hook, libc `abort()` diagnostics, glibc backtraces, and
/// any kernel signal-default output land in a durable location instead
/// of `/dev/null` (which is where the `MiSTer` wrapper sends stderr).
pub fn stderr_log_path() -> PathBuf {
    if runtime::current().is_mister() {
        PathBuf::from("/tmp/zaparoo/frontend.stderr.log")
    } else {
        dirs_next::data_local_dir()
            .unwrap_or_else(|| PathBuf::from("."))
            .join("zaparoo")
            .join("logs")
            .join("frontend.stderr.log")
    }
}

pub fn state_file_path() -> PathBuf {
    // ZAPAROO_STATE_FILE lets tests (and ad-hoc runs) redirect state
    // persistence away from the real user path. Checked first so the
    // override applies on every platform.
    if let Ok(custom) = std::env::var("ZAPAROO_STATE_FILE") {
        if !custom.is_empty() {
            return PathBuf::from(custom);
        }
    }
    if runtime::current().is_mister() {
        PathBuf::from("/tmp/zaparoo/state.toml")
    } else {
        let mut path = config_file_path();
        path.set_file_name("state.toml");
        path
    }
}

/// Directory containing per-sponsor folders (see `credits` module).
/// On `MiSTer` this is the install-bundled (or agent-synced) location
/// alongside `frontend.toml`. On dev hosts it lands next to the
/// dev config directory so contributors can manually drop a credits
/// dir there to test the Credits screen without a real cabinet.
pub fn credits_dir_path() -> PathBuf {
    if runtime::current().is_mister() {
        PathBuf::from("/media/fat/zaparoo/credits")
    } else {
        dirs_next::config_dir()
            .unwrap_or_else(|| PathBuf::from("."))
            .join("zaparoo")
            .join("credits")
    }
}

/// Directory containing per-artist folders. Mirrors `credits_dir_path`
/// — same on-disk schema (`<dir>/<slug>/metadata.toml` + `logo.png`),
/// reuses the same `credits::load_credits` loader. Sibling of the
/// credits dir rather than a nested subdir so the existing
/// sponsor-sync logic stays untouched.
pub fn artists_dir_path() -> PathBuf {
    if runtime::current().is_mister() {
        PathBuf::from("/media/fat/zaparoo/artists")
    } else {
        dirs_next::config_dir()
            .unwrap_or_else(|| PathBuf::from("."))
            .join("zaparoo")
            .join("artists")
    }
}

/// Directory containing per-person Dev Team folders. Same schema as
/// `credits_dir_path` / `artists_dir_path` — reuses the same loader.
/// Surfaced via `Browse.DevTeam` to the Credits → Dev Team screen.
pub fn dev_team_dir_path() -> PathBuf {
    if runtime::current().is_mister() {
        PathBuf::from("/media/fat/zaparoo/devteam")
    } else {
        dirs_next::config_dir()
            .unwrap_or_else(|| PathBuf::from("."))
            .join("zaparoo")
            .join("devteam")
    }
}

/// Directory containing per-section About / Potions & Pixels cards.
/// Each folder is one card on the Credits → Potions & Pixels
/// scrollable view (section title + body + optional image). Same
/// schema as `credits_dir_path` — reuses the same loader. Surfaced
/// via `Browse.About`.
pub fn about_dir_path() -> PathBuf {
    if runtime::current().is_mister() {
        PathBuf::from("/media/fat/zaparoo/about")
    } else {
        dirs_next::config_dir()
            .unwrap_or_else(|| PathBuf::from("."))
            .join("zaparoo")
            .join("about")
    }
}

#[cfg(test)]
mod tests {
    #![allow(
        clippy::expect_used,
        clippy::unwrap_used,
        clippy::panic,
        reason = "tests should fail-fast on unexpected errors"
    )]

    use super::{config_file_path, log_file_path, state_file_path, stderr_log_path};
    use crate::runtime;

    #[test]
    fn paths_end_with_expected_filenames() {
        let cfg = config_file_path();
        assert_eq!(
            cfg.file_name().and_then(|n| n.to_str()),
            Some("frontend.toml")
        );

        let log = log_file_path();
        assert_eq!(
            log.file_name().and_then(|n| n.to_str()),
            Some("frontend.log")
        );

        let stderr_log = stderr_log_path();
        assert_eq!(
            stderr_log.file_name().and_then(|n| n.to_str()),
            Some("frontend.stderr.log")
        );

        let state = state_file_path();
        assert_eq!(
            state.file_name().and_then(|n| n.to_str()),
            Some("state.toml")
        );
    }

    #[test]
    fn runtime_matches_configured_paths() {
        // When runtime is Desktop, paths route through dirs_next (per-user dirs)
        // rather than the fixed MiSTer locations. Asserts the branches stay in sync.
        if runtime::current().is_mister() {
            assert_eq!(
                config_file_path().to_str(),
                Some("/media/fat/zaparoo/frontend.toml")
            );
            assert_eq!(log_file_path().to_str(), Some("/tmp/zaparoo/frontend.log"));
            assert_eq!(
                stderr_log_path().to_str(),
                Some("/tmp/zaparoo/frontend.stderr.log")
            );
            assert_eq!(state_file_path().to_str(), Some("/tmp/zaparoo/state.toml"));
        } else {
            let cfg = config_file_path();
            assert!(
                cfg.ends_with("zaparoo/frontend.toml"),
                "config path did not end with zaparoo/frontend.toml: {cfg:?}"
            );
            let log = log_file_path();
            assert!(
                log.ends_with("zaparoo/logs/frontend.log"),
                "log path did not end with zaparoo/logs/frontend.log: {log:?}"
            );
            let stderr_log = stderr_log_path();
            assert!(
                stderr_log.ends_with("zaparoo/logs/frontend.stderr.log"),
                "stderr log path did not end with zaparoo/logs/frontend.stderr.log: {stderr_log:?}"
            );
            let state = state_file_path();
            assert!(
                state.ends_with("zaparoo/state.toml"),
                "state path did not end with zaparoo/state.toml: {state:?}"
            );
        }
    }

    #[test]
    fn state_file_sits_next_to_config_file_on_desktop() {
        if runtime::current().is_mister() {
            return;
        }
        let cfg = config_file_path();
        let state = state_file_path();
        assert_eq!(
            cfg.parent(),
            state.parent(),
            "state.toml must be a sibling of frontend.toml: cfg={cfg:?} state={state:?}"
        );
    }
}
