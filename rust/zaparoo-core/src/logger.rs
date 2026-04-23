// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0
// SPDX-FileCopyrightText: 2026 Callan Barrett

use crate::config::Config;
use crate::platform_paths::log_file_path;
use std::path::Path;
use tracing_appender::non_blocking::WorkerGuard;
use tracing_subscriber::{EnvFilter, fmt, layer::SubscriberExt, util::SubscriberInitExt};

// Returned from install(); must be held for the process lifetime to keep the
// file-appender thread alive. Drop causes a flush + shutdown.
pub struct LoggerGuard {
    _file_guard: WorkerGuard,
}

pub fn install(config: &Config) -> LoggerGuard {
    let log_path = log_file_path();
    if let Some(dir) = log_path.parent() {
        let _ = std::fs::create_dir_all(dir);
    }
    install_at(config, &log_path)
}

pub fn install_at(config: &Config, log_path: &Path) -> LoggerGuard {
    let debug = config.debug_logging || std::env::var("ZAPAROO_DEBUG").is_ok_and(|v| v != "0" && v != "false");

    let file_appender = tracing_appender::rolling::never(
        log_path.parent().unwrap_or(Path::new(".")),
        log_path.file_name().unwrap_or_default(),
    );
    let (non_blocking_file, file_guard) = tracing_appender::non_blocking(file_appender);

    let stderr_layer = fmt::layer()
        .with_writer(std::io::stderr)
        .with_ansi(false)
        .with_target(false)
        .with_timer(fmt::time::LocalTime::rfc_3339());

    let file_layer = fmt::layer()
        .with_writer(non_blocking_file)
        .with_ansi(false)
        .json()
        .with_timer(fmt::time::UtcTime::rfc_3339());

    let filter = if debug {
        EnvFilter::new("debug")
    } else {
        EnvFilter::new("info")
    };

    tracing_subscriber::registry()
        .with(filter)
        .with(stderr_layer)
        .with(file_layer)
        .init();

    LoggerGuard { _file_guard: file_guard }
}
