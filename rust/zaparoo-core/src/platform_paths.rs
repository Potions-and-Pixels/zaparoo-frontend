// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0
// SPDX-FileCopyrightText: 2026 Callan Barrett

use std::path::PathBuf;

pub fn is_mister() -> bool {
    std::path::Path::new("/media/fat").exists()
}

pub fn config_file_path() -> PathBuf {
    if is_mister() {
        PathBuf::from("/media/fat/zaparoo/launcher.toml")
    } else {
        dirs_next::config_dir()
            .unwrap_or_else(|| PathBuf::from("."))
            .join("zaparoo")
            .join("launcher.toml")
    }
}

pub fn log_file_path() -> PathBuf {
    if is_mister() {
        PathBuf::from("/tmp/zaparoo/launcher.log")
    } else {
        dirs_next::data_local_dir()
            .unwrap_or_else(|| PathBuf::from("."))
            .join("zaparoo")
            .join("logs")
            .join("launcher.log")
    }
}
