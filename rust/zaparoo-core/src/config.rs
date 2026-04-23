// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0
// SPDX-FileCopyrightText: 2026 Callan Barrett

use serde::Deserialize;
use std::path::Path;
use tracing::warn;

#[derive(Debug, Clone)]
pub struct Config {
    pub core_endpoint: String,
    pub video_width: u32,
    pub video_height: u32,
    pub debug_logging: bool,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            core_endpoint: "ws://localhost:7497/api/v0.1".into(),
            video_width: 1920,
            video_height: 1080,
            debug_logging: false,
        }
    }
}

#[derive(Deserialize, Default)]
struct RawConfig {
    #[serde(default)]
    core: RawCore,
    #[serde(default)]
    video: RawVideo,
    #[serde(default)]
    logging: RawLogging,
}

#[derive(Deserialize, Default)]
struct RawCore {
    endpoint: Option<String>,
}

#[derive(Deserialize, Default)]
struct RawVideo {
    width: Option<u32>,
    height: Option<u32>,
}

#[derive(Deserialize, Default)]
struct RawLogging {
    debug: Option<bool>,
}

pub fn load_config(path: &Path) -> Config {
    let mut cfg = Config::default();
    let src = match std::fs::read_to_string(path) {
        Ok(s) => s,
        Err(_) => return cfg,
    };
    let raw: RawConfig = match toml::from_str(&src) {
        Ok(r) => r,
        Err(e) => {
            warn!("config parse error in {}: {e}", path.display());
            return cfg;
        }
    };
    if let Some(ep) = raw.core.endpoint {
        cfg.core_endpoint = ep;
    }
    if let Some(w) = raw.video.width {
        cfg.video_width = w;
    }
    if let Some(h) = raw.video.height {
        cfg.video_height = h;
    }
    if let Some(d) = raw.logging.debug {
        cfg.debug_logging = d;
    }
    cfg
}
