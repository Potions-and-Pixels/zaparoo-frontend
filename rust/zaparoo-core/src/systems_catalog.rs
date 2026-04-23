// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0
// SPDX-FileCopyrightText: 2026 Callan Barrett
//
// Fetches the systems list once on every connection event and broadcasts
// a parsed CatalogData to subscribers (the QObject models).

use crate::client::Client;
use crate::media_types::{SystemInfo, SystemsParams};
use std::collections::HashSet;
use std::sync::Arc;
use tokio::sync::watch;
use tracing::{info, warn};

#[derive(Debug, Clone)]
pub struct CatalogData {
    pub systems: Vec<SystemInfo>,
    pub categories: Vec<String>,
}

impl CatalogData {
    pub fn systems_by_category(&self, category: &str) -> Vec<SystemInfo> {
        let is_other = category.eq_ignore_ascii_case("Other");
        self.systems
            .iter()
            .filter(|s| {
                if is_other {
                    s.category.is_empty()
                } else {
                    s.category.eq_ignore_ascii_case(category)
                }
            })
            .cloned()
            .collect()
    }
}

fn derive_categories(systems: &[SystemInfo]) -> Vec<String> {
    let mut seen: HashSet<String> = HashSet::new();
    let mut cats: Vec<String> = Vec::new();
    for s in systems {
        let cat = if s.category.is_empty() { "Other".to_string() } else { s.category.clone() };
        let lower = cat.to_lowercase();
        if seen.insert(lower) {
            cats.push(cat);
        }
    }
    cats.sort_by(|a, b| a.to_lowercase().cmp(&b.to_lowercase()));
    cats
}

pub fn spawn(
    client: Arc<Client>,
    runtime: Arc<tokio::runtime::Runtime>,
) -> watch::Sender<Option<CatalogData>> {
    let (catalog_tx, _) = watch::channel(None::<CatalogData>);
    let tx = catalog_tx.clone();
    // Subscribe before spawning: broadcast receivers miss messages sent before
    // subscription, so if the core is already up the "connected = true" event
    // would arrive before the async task even starts. Subscribing here on the
    // main thread guarantees we capture it.
    let mut connected_rx = client.connected.subscribe();

    runtime.spawn(async move {
        loop {
            match connected_rx.recv().await {
                Ok(true) => {
                    let seq_client = client.clone();
                    match seq_client.systems(SystemsParams {}).await {
                        Ok(result) => {
                            let mut systems = result.systems;
                            systems.sort_by(|a, b| {
                                a.name.to_lowercase().cmp(&b.name.to_lowercase())
                            });
                            let categories = derive_categories(&systems);
                            info!(
                                "catalog loaded: {} systems, {} categories",
                                systems.len(),
                                categories.len()
                            );
                            tx.send_replace(Some(CatalogData { systems, categories }));
                        }
                        Err(e) => warn!("systems RPC failed: {}", e.message),
                    }
                }
                Ok(false) => {}
                Err(_) => break,
            }
        }
    });

    catalog_tx
}
