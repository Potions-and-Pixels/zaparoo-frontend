// Zaparoo Frontend
// Copyright (c) 2026 Wizzo Pty Ltd and the Zaparoo Project contributors.
// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0
//
// `MediaPresenceEndpoint` — the two sets that `hide_empty_categories`
// needs to prune the Hub grid AND the SystemsScreen tile list:
//
//   `categories` — every category name that has at least one indexed
//                  media entry on THIS cabinet
//   `system_ids` — every system id that has at least one indexed media
//                  entry on THIS cabinet
//
// Derived from a full walk of `media.search` (empty query, paginated).
// Distinct from `CatalogEndpoint`, which exposes every category /
// system Core's systemdefs declare — those are declared, not indexed.
// The fork's `hide_empty_categories` filter wants the narrower
// "actually launchable on this SD card" answer at every browse level
// so operators aren't sent down tiles that go nowhere.
//
// Retained legacy name `media_categories` on the file + module for
// git-blame continuity with the initial single-set fork addition
// (2026-08-30); the type name reflects the widened scope.
//
// `Args = ()`: single global instance shared across subscribers; the
// tag `Tag::specific("MediaPresence", "")` scopes the cache entry so
// unrelated per-system MediaSearch subscriptions can't collide.
//
// Invalidated by `MediaTagsUpdate` (via `Tag::any(Self::NAME)`), same
// mutation that invalidates `MediaSearchEndpoint` /
// `MediaBrowseEndpoint`. A media rescan (`media.generate`) requires a
// resubscribe / restart to reflect; on kiosk cabinets rescans are
// rare so the tradeoff is acceptable for now.

use crate::client::{Client, ClientError};
use crate::media_types::MediaSearchParams;
use crate::store::{Endpoint, Tag};
use futures_util::future::BoxFuture;
use std::collections::HashSet;
use std::sync::Arc;

/// Backstop: absolute maximum media rows we'll page through before
/// bailing out. Even a fully-loaded MiSTer library (~10K games) fits
/// well under this; the ceiling exists so a Core bug returning
/// `has_next_page = true` forever can't lock the endpoint's fetch.
const MAX_PAGES: usize = 200;
const PAGE_SIZE: u32 = 500;

/// Set of category names AND system ids that have at least one indexed
/// media entry on THIS cabinet. Populated by walking `media.search`
/// with an empty query. Case-preserved as Core returns; consumers
/// (`CategoriesModel`, `SystemsModel`) compare case-insensitively
/// against their respective `raw` lists.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct MediaPresence {
    pub categories: HashSet<String>,
    pub system_ids: HashSet<String>,
}

#[derive(Debug)]
pub struct MediaPresenceEndpoint;

/// Type alias kept only for the fork's initial rename (2026-08-30).
/// Delete once `frontend/src/models/categories.rs` no longer references
/// the older name; retained for one commit so `git blame` reads clean.
pub type MediaCategoriesEndpoint = MediaPresenceEndpoint;

impl Endpoint for MediaPresenceEndpoint {
    type Args = ();
    type Output = MediaPresence;
    const NAME: &'static str = "MediaPresence";

    fn fetch(
        client: Arc<Client>,
        (): Self::Args,
    ) -> BoxFuture<'static, Result<Self::Output, ClientError>> {
        Box::pin(async move {
            let mut presence = MediaPresence::default();
            let mut cursor: Option<String> = None;
            for _ in 0..MAX_PAGES {
                let params = MediaSearchParams {
                    max_results: Some(PAGE_SIZE),
                    cursor: cursor.clone(),
                    ..MediaSearchParams::default()
                };
                let res = client.media_search(params).await?;
                for item in &res.results {
                    // System id — every indexed entry has one; skip if
                    // Core somehow returns a blank.
                    let sid = item.system.id.trim();
                    if !sid.is_empty() {
                        presence.system_ids.insert(sid.to_string());
                    }
                    // Category — empty string canonicalized to "Other",
                    // matching `CatalogData::systems_by_category`'s
                    // treatment of the synthesized bucket.
                    let cat = item.system.category.trim();
                    if cat.is_empty() {
                        presence.categories.insert("Other".to_string());
                    } else {
                        presence.categories.insert(cat.to_string());
                    }
                }
                let Some(p) = res.pagination.as_ref() else { break };
                if !p.has_next_page {
                    break;
                }
                let Some(next) = p.next_cursor.clone() else { break };
                cursor = Some(next);
            }
            Ok(presence)
        })
    }

    fn provides(_args: &Self::Args, _output: &Self::Output) -> Vec<Tag> {
        vec![Tag::specific(Self::NAME, String::new())]
    }
}
