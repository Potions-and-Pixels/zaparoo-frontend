// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0
// SPDX-FileCopyrightText: 2026 Callan Barrett

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SystemInfo {
    pub id: String,
    pub name: String,
    #[serde(default)]
    pub category: String,
}

#[derive(Debug, Clone, Default)]
pub struct MediaSearchParams {
    pub systems: Vec<String>,
    pub max_results: u32,
}

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MediaItem {
    pub name: String,
    pub path: String,
    #[serde(default)]
    pub zap_script: String,
    #[serde(default)]
    pub system: SystemRef,
}

#[derive(Debug, Clone, Default, Deserialize)]
pub struct SystemRef {
    pub id: String,
}

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MediaSearchResult {
    pub results: Vec<MediaItem>,
    #[serde(default)]
    pub has_next_page: bool,
}

#[derive(Debug, Clone, Default, Serialize)]
pub struct MediaBrowseParams {
    pub path: String,
}

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BrowseEntry {
    pub name: String,
    pub path: String,
    #[serde(rename = "type", default)]
    pub entry_type: String,
    #[serde(default)]
    pub file_count: u32,
}

impl BrowseEntry {
    pub fn is_folder(&self) -> bool {
        self.entry_type == "folder" || self.entry_type == "directory"
    }
}

#[derive(Debug, Clone, Default, Deserialize)]
pub struct MediaBrowseResult {
    pub entries: Vec<BrowseEntry>,
}

#[derive(Debug, Clone, Default, Serialize)]
pub struct RunParams {
    pub text: String,
}

#[derive(Debug, Clone, Default, Deserialize)]
pub struct RunResult {}

#[derive(Debug, Clone, Default, Serialize)]
pub struct SystemsParams {}

#[derive(Debug, Clone, Default, Deserialize)]
pub struct SystemsResult {
    pub systems: Vec<SystemInfo>,
}
