// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0
// SPDX-FileCopyrightText: 2026 Callan Barrett

mod mister_runtime;
mod models;

use std::ffi::c_int;
use std::sync::Arc;
use zaparoo_core::{client::Client, config::load_config, logger::install, platform_paths::config_file_path, systems_catalog};

/// Called by the C++ main before QGuiApplication is constructed.
/// Sets up logging, tokio runtime, MiSTer pre-Qt env/vmode, WebSocket
/// client, SystemsCatalog, and model globals. Returns 0 on success.
#[no_mangle]
pub extern "C" fn zaparoo_rust_init() -> c_int {
    let config_path = config_file_path();
    let config = load_config(&config_path);

    // Leak the guard — it must live for the process lifetime to keep the
    // file-appender thread running. The OS reclaims it on exit.
    let guard = install(&config);
    Box::leak(Box::new(guard));

    tracing::info!("Zaparoo Launcher starting");

    let runtime = Arc::new(
        tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()
            .expect("tokio runtime"),
    );

    mister_runtime::apply_pre_qt_setup(&config);

    let client = Client::new(config.core_endpoint.clone(), runtime.clone());
    let catalog_tx = systems_catalog::spawn(client.clone(), runtime.clone());

    // init_globals stores Arcs — runtime keeps running after this fn returns.
    models::init_globals(runtime, client, catalog_tx);

    0
}

/// Called by the C++ main after the QML engine has loaded but before exec().
/// Fires the Zaparoo Core service start (MiSTer only, no-op on desktop).
#[no_mangle]
pub extern "C" fn zaparoo_rust_post_qt_start() {
    mister_runtime::ensure_core_service_running();
}
