// Zaparoo Frontend
// Copyright (c) 2026 Wizzo Pty Ltd and the Zaparoo Project contributors.
// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0

use crate::models::{
    global_handle, global_store, hide_empty_categories_flag, with_hidden_browse_prefs_read,
    with_persist_read,
};
use cxx_qt::{CxxQtType, Initialize, Threading};
use cxx_qt_lib::{QByteArray, QHash, QHashPair_i32_QByteArray, QModelIndex, QString, QVariant};
use std::collections::HashSet;
use std::pin::Pin;
use tracing::debug;
use zaparoo_core::endpoints::catalog::CatalogEndpoint;
use zaparoo_core::endpoints::media_categories::{MediaPresence, MediaPresenceEndpoint};
use zaparoo_core::remote_resource::ResourceStatus;
use zaparoo_core::systems_catalog::CatalogData;

const NAME_ROLE: i32 = 256 + 1; // Qt::UserRole + 1
const COVER_KEY_ROLE: i32 = 256 + 2;
const HIDDEN_ROLE: i32 = 256 + 3;

// Categories Core surfaces but the frontend doesn't expose. `Media` is
// reserved for non-game content the frontend doesn't have a screen for
// yet (tracked in #21). `Other` — the synthesized bucket for systems with
// no upstream category — is now surfaced: Core's launchables (launch-only
// virtual systems) land there, so it carries real, launchable content.
const HIDDEN_CATEGORIES: &[&str] = &["Media"];

#[derive(Default)]
pub struct CategoriesModelRust {
    /// Raw category list received from Core. Stored so `reproject()` can
    /// re-filter without waiting for a catalog refetch.
    raw: Vec<String>,
    /// Category names with at least one indexed media entry on THIS
    /// cabinet, from `MediaCategoriesEndpoint`. Fork-only:
    /// `hide_empty_categories` uses this set (not the CatalogEndpoint's
    /// systems-per-category count) so a category is dropped iff no game
    /// on THIS SD card belongs to it. Case-preserved as Core reports;
    /// `visible_categories` compares case-insensitively.
    media_categories: HashSet<String>,
    /// Filtered+visible category names in display order.
    categories: Vec<String>,
    /// Parallel to `categories`: true when the category is user-hidden but
    /// visible because `show_hidden` is on. Always false for unhidden items.
    hidden_flags: Vec<bool>,
    count: i32,
    raw_count: i32,
    /// Count of indexed (non-launchable) systems in the catalog. Distinct
    /// from `count` (visible categories) and `raw_count` (all categories):
    /// Core's launchables surface as systems under the `Other` category
    /// even with no media-db index, so `count`/`raw_count` are non-zero on
    /// a fresh device. `indexed_count` ignores launchables, so the first-
    /// run scan prompt in `Main.qml` can tell "no games indexed yet" apart
    /// from "only launchables present".
    indexed_count: i32,
    // Sticky-true flag: flips to true the first time the catalog
    // resolves Ready, never resets. The first-run modal in
    // `Main.qml` gates on `loaded && count === 0` so it only fires
    // after we've seen an authoritative empty catalog — without
    // this we'd misread the initial Default state (count=0,
    // pre-fetch) as "no systems" and fire the modal on every cold
    // launch before Core has answered.
    loaded: bool,
    error_message: QString,
}

#[cxx_qt::bridge]
pub mod ffi {
    unsafe extern "C++" {
        include!("model_includes.h");

        #[allow(non_snake_case, reason = "Qt class names are PascalCase")]
        type QAbstractListModel;

        type QModelIndex = cxx_qt_lib::QModelIndex;
        type QVariant = cxx_qt_lib::QVariant;
        type QHash_i32_QByteArray = cxx_qt_lib::QHash<cxx_qt_lib::QHashPair_i32_QByteArray>;
        type QByteArray = cxx_qt_lib::QByteArray;
        type QString = cxx_qt_lib::QString;
    }

    unsafe extern "RustQt" {
        #[qobject]
        #[base = QAbstractListModel]
        #[qml_element]
        #[qml_singleton]
        #[qproperty(i32, count)]
        #[qproperty(i32, raw_count)]
        #[qproperty(i32, indexed_count)]
        #[qproperty(bool, loaded)]
        #[qproperty(QString, error_message)]
        type CategoriesModel = super::CategoriesModelRust;

        #[qinvokable]
        fn category_at(self: &CategoriesModel, index: i32) -> QString;

        #[qinvokable]
        fn index_for_category(self: &CategoriesModel, name: &QString) -> i32;

        /// Returns true when the category at `index` is user-hidden and
        /// `show_hidden` is on.
        #[qinvokable]
        fn is_hidden_at(self: &CategoriesModel, index: i32) -> bool;

        /// Re-filter the categories list using the current persisted hidden set
        /// and `show_hidden`. Call after any hide/unhide/toggle so the hub grid
        /// reflects new visibility without waiting for a catalog refetch.
        #[qinvokable]
        fn reproject(self: Pin<&mut CategoriesModel>);

        #[inherit]
        #[cxx_name = "beginResetModel"]
        fn begin_reset_model(self: Pin<&mut CategoriesModel>);

        #[inherit]
        #[cxx_name = "endResetModel"]
        fn end_reset_model(self: Pin<&mut CategoriesModel>);

        // QAbstractListModel virtual overrides
        #[cxx_name = "rowCount"]
        fn row_count(self: &CategoriesModel, parent: &QModelIndex) -> i32;
        fn data(self: &CategoriesModel, index: &QModelIndex, role: i32) -> QVariant;
        #[cxx_name = "roleNames"]
        fn role_names(self: &CategoriesModel) -> QHash_i32_QByteArray;
    }

    impl cxx_qt::Threading for CategoriesModel {}
    impl cxx_qt::Initialize for CategoriesModel {}
}

/// Hand-written `Initialize` — replaces the `bind_to_endpoint!` macro
/// so this model can subscribe to TWO endpoints (Catalog + fork-only
/// MediaCategories) instead of the macro's one. Same sync-seed + Qt-thread
/// dispatch contract as the macro; see `bind.rs` for the invariants.
///
/// Two separate tokio watchers so each endpoint's changes are applied
/// independently: a catalog update won't stall waiting for MediaCategories
/// to refetch and vice versa. Both apply paths funnel through
/// `reproject_inner` so the final visible-categories list always reflects
/// the freshest of both streams.
impl Initialize for ffi::CategoriesModel {
    fn initialize(mut self: Pin<&mut Self>) {
        let started = std::time::Instant::now();
        crate::startup_trace("rust:model CategoriesModel init start");

        let mut rx_catalog = global_store()
            .subscribe::<CatalogEndpoint>(())
            .subscribe();
        let projected = project(&*rx_catalog.borrow_and_update());
        apply_state(self.as_mut(), projected);

        let mut rx_media = global_store()
            .subscribe::<MediaPresenceEndpoint>(())
            .subscribe();
        let media_snap = project_media(&*rx_media.borrow_and_update());
        apply_media_state(self.as_mut(), media_snap);

        crate::startup_trace(format!(
            "rust:model CategoriesModel init seeded dur_ms={}",
            started.elapsed().as_millis()
        ));

        let qt_thread_catalog = self.qt_thread();
        let qt_thread_media = self.qt_thread();

        global_handle().spawn(async move {
            while rx_catalog.changed().await.is_ok() {
                let projected = project(&*rx_catalog.borrow_and_update());
                let _ = qt_thread_catalog.queue(move |m| apply_state(m, projected));
            }
        });
        global_handle().spawn(async move {
            while rx_media.changed().await.is_ok() {
                let snap = project_media(&*rx_media.borrow_and_update());
                let _ = qt_thread_media.queue(move |m| apply_media_state(m, snap));
            }
        });

        crate::startup_trace(format!(
            "rust:model CategoriesModel init end dur_ms={}",
            started.elapsed().as_millis()
        ));
    }
}

/// Pull the pieces this model cares about out of the unified
/// `ResourceStatus`: the raw category list, the indexed system count,
/// and the surfaced error message (empty unless `Errored`). Filtering
/// is deferred to `apply_state` / `reproject_inner` so `reproject()`
/// can re-filter in-place without waiting for a catalog refetch.
fn project(
    status: &ResourceStatus<CatalogData>,
) -> (Option<(Vec<String>, i32)>, String) {
    match status {
        ResourceStatus::Ready(data) => (
            Some((data.categories.clone(), data.indexed_count() as i32)),
            String::new(),
        ),
        ResourceStatus::Errored { message, .. } => (None, message.clone()),
        ResourceStatus::Idle | ResourceStatus::Loading => (None, String::new()),
    }
}

/// Pull the categories-with-media set out of `MediaPresenceEndpoint`'s
/// resource status (we only need `.categories` here — `SystemsModel`
/// consumes `.system_ids` from the same shared endpoint). Errored /
/// Loading collapse to `None` so a transient backend failure doesn't
/// silently drop every category from the Hub — `apply_media_state`
/// skips the update in that case, leaving the last known set in place.
fn project_media(status: &ResourceStatus<MediaPresence>) -> Option<HashSet<String>> {
    match status {
        ResourceStatus::Ready(presence) => Some(presence.categories.clone()),
        _ => None,
    }
}

/// Find `needle` in `haystack` with case-sensitive equality. Returns
/// the position as i32, or -1 if not found / empty needle. The
/// case-sensitive contract is deliberate: `HubState.category` is
/// persisted to disk and the frontend re-derives the row index from
/// that string. A case-insensitive lookup would silently coerce
/// "consoles" into "Consoles" if Core ever returned mixed case,
/// hiding a real upstream bug. Pulled out of `index_for_category`
/// so the contract is unit-testable without a `QObject` instance.
fn position_of(haystack: &[String], needle: &str) -> i32 {
    if needle.is_empty() {
        return -1;
    }
    haystack
        .iter()
        .position(|c| c == needle)
        .map_or(-1, |i| i as i32)
}

/// Apply the frontend-side category presentation rules to the raw list from
/// Core, returning the filtered names and a parallel hidden-flag vector.
///
/// Always drops built-in `HIDDEN_CATEGORIES` (case-insensitive). For
/// `user_hidden` (case-sensitive equality — matches the persisted category
/// string exactly): drops the entry when `show_hidden` is false, includes it
/// with `hidden = true` when true.
///
/// When `hide_empty` is true AND `show_hidden` is false, additionally
/// drops any category NOT present in `media_categories` — the set of
/// categories that have at least one indexed media entry on THIS
/// cabinet (from `MediaCategoriesEndpoint`). This is what "empty" means
/// from the operator's POV: no launchable game on this SD card, not
/// "no system Core knows about" (Core's systemdefs list every possible
/// system regardless of what's installed). Match is case-insensitive so
/// a "Console" tile still counts when Core reports "console" for the
/// system's category on the media entry.
///
/// If `media_categories` is empty AND `hide_empty` is true, the filter
/// is a no-op — an empty set means MediaCategoriesEndpoint hasn't
/// resolved yet (initial boot before `media.search` returns) and
/// dropping every category would flash an empty Hub while the async
/// fetch is in-flight.
///
/// Pulled out of `apply_state` for test coverage.
fn visible_categories(
    raw: &[String],
    media_categories: &HashSet<String>,
    user_hidden: &[String],
    show_hidden: bool,
    hide_empty: bool,
) -> (Vec<String>, Vec<bool>) {
    let mut names = Vec::with_capacity(raw.len());
    let mut flags = Vec::with_capacity(raw.len());
    let apply_empty_filter = hide_empty && !show_hidden && !media_categories.is_empty();
    for c in raw {
        if HIDDEN_CATEGORIES
            .iter()
            .any(|hidden| c.eq_ignore_ascii_case(hidden))
        {
            continue;
        }
        let is_user_hidden = user_hidden.iter().any(|h| h == c);
        if is_user_hidden && !show_hidden {
            continue;
        }
        if apply_empty_filter
            && !media_categories
                .iter()
                .any(|m| m.eq_ignore_ascii_case(c))
        {
            continue;
        }
        names.push(c.clone());
        flags.push(is_user_hidden);
    }
    (names, flags)
}

/// Re-run the visibility filter in-place using the current persisted state.
/// Wraps `begin/endResetModel` + `count_changed` + the `loaded` sticky flag.
fn reproject_inner(mut model: Pin<&mut ffi::CategoriesModel>) {
    let user_hidden = with_hidden_browse_prefs_read(|p| p.hidden_categories.clone());
    let show_hidden = with_persist_read(|s| s.settings.show_hidden);
    let raw = model.rust().raw.clone();
    let media_categories = model.rust().media_categories.clone();
    let hide_empty = hide_empty_categories_flag();
    let (names, flags) = visible_categories(
        &raw,
        &media_categories,
        &user_hidden,
        show_hidden,
        hide_empty,
    );
    let count = names.len() as i32;
    debug!(count, categories = ?names, "categories: reproject_inner");
    model.as_mut().begin_reset_model();
    model.as_mut().rust_mut().categories = names;
    model.as_mut().rust_mut().hidden_flags = flags;
    model.as_mut().rust_mut().count = count;
    model.as_mut().end_reset_model();
    model.as_mut().count_changed();
    if !model.loaded {
        model.as_mut().set_loaded(true);
    }
}

fn apply_state(
    mut model: Pin<&mut ffi::CategoriesModel>,
    (ready, err): (Option<(Vec<String>, i32)>, String),
) {
    if let Some((raw, indexed_count)) = ready {
        let raw_count = raw.len() as i32;
        model.as_mut().rust_mut().raw = raw;
        if model.raw_count != raw_count {
            model.as_mut().rust_mut().raw_count = raw_count;
            model.as_mut().raw_count_changed();
        }
        if model.indexed_count != indexed_count {
            model.as_mut().rust_mut().indexed_count = indexed_count;
            model.as_mut().indexed_count_changed();
        }
        reproject_inner(model.as_mut());
    }
    let qerr = QString::from(err.as_str());
    if model.error_message != qerr {
        model.as_mut().set_error_message(qerr);
    }
}

/// Companion to `apply_state` — handles the `MediaCategoriesEndpoint`
/// side. `None` (fetch still Loading / Errored) is a no-op so the last
/// known good set survives while a refetch is in-flight; on success,
/// stashes the set and reprojects so the Hub picks up the new filter.
fn apply_media_state(
    mut model: Pin<&mut ffi::CategoriesModel>,
    snap: Option<HashSet<String>>,
) {
    let Some(new) = snap else { return };
    if new == model.rust().media_categories {
        return;
    }
    debug!(
        count = new.len(),
        categories = ?new,
        "categories: media_categories update"
    );
    model.as_mut().rust_mut().media_categories = new;
    reproject_inner(model.as_mut());
}

impl ffi::CategoriesModel {
    fn row_count(&self, parent: &QModelIndex) -> i32 {
        if parent.is_valid() {
            0
        } else {
            self.count
        }
    }

    fn data(&self, index: &QModelIndex, role: i32) -> QVariant {
        if !index.is_valid() || index.row() < 0 || index.row() >= self.count {
            return QVariant::default();
        }
        let row = index.row() as usize;
        match role {
            NAME_ROLE => {
                let s = &self.categories[row];
                QVariant::from(&QString::from(s.as_str()))
            }
            COVER_KEY_ROLE => {
                // Relative path under `resources/images/` (no extension).
                // Categories without a curated PNG (anything we haven't
                // bundled yet) still emit a key — Tile's Image fails to
                // resolve and the procedural fallback takes over.
                let s = &self.categories[row];
                QVariant::from(&QString::from(format!("categories/{s}").as_str()))
            }
            HIDDEN_ROLE => QVariant::from(&self.hidden_flags[row]),
            _ => QVariant::default(),
        }
    }

    fn role_names(&self) -> QHash<QHashPair_i32_QByteArray> {
        let mut hash = QHash::<QHashPair_i32_QByteArray>::default();
        hash.insert(NAME_ROLE, QByteArray::from("name"));
        hash.insert(COVER_KEY_ROLE, QByteArray::from("coverKey"));
        hash.insert(HIDDEN_ROLE, QByteArray::from("hidden"));
        hash
    }

    fn category_at(&self, index: i32) -> QString {
        if index < 0 || index >= self.count {
            return QString::default();
        }
        QString::from(self.categories[index as usize].as_str())
    }

    fn index_for_category(&self, name: &QString) -> i32 {
        position_of(&self.categories, &name.to_string())
    }

    fn is_hidden_at(&self, index: i32) -> bool {
        if index < 0 || index >= self.count {
            return false;
        }
        self.hidden_flags[index as usize]
    }

    fn reproject(self: Pin<&mut Self>) {
        reproject_inner(self);
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

    use super::{position_of, visible_categories};
    use std::collections::HashSet;

    // Shorthand: existing tests don't exercise the empty-category
    // filter, so pass an empty media set + `hide_empty = false` and
    // pre-flag behavior is unchanged.
    fn vc(
        raw: &[String],
        user_hidden: &[String],
        show_hidden: bool,
    ) -> (Vec<String>, Vec<bool>) {
        visible_categories(raw, &HashSet::new(), user_hidden, show_hidden, false)
    }

    fn media_set(cats: &[&str]) -> HashSet<String> {
        cats.iter().map(|s| (*s).to_string()).collect()
    }

    #[test]
    fn position_of_returns_index_on_case_exact_match() {
        let items = vec!["Consoles".to_string(), "Arcade".to_string()];
        assert_eq!(position_of(&items, "Arcade"), 1);
    }

    #[test]
    fn position_of_is_case_sensitive_and_returns_minus_one_on_mismatch() {
        let items = vec!["Consoles".to_string(), "Arcade".to_string()];
        // Mixed case must NOT match — HubState.category is persisted as
        // an exact string and the lookup is case-sensitive on purpose.
        assert_eq!(position_of(&items, "arcade"), -1);
        assert_eq!(position_of(&items, "ARCADE"), -1);
    }

    #[test]
    fn position_of_empty_needle_returns_minus_one() {
        let items = vec!["Consoles".to_string()];
        assert_eq!(position_of(&items, ""), -1);
    }

    #[test]
    fn position_of_missing_returns_minus_one() {
        let items = vec!["Consoles".to_string()];
        assert_eq!(position_of(&items, "Missing"), -1);
    }

    #[test]
    fn raw_categories_pass_through_in_order() {
        let raw = vec!["Consoles".to_string(), "Arcade".to_string()];
        let (names, flags) = vc(&raw, &[], false);
        assert_eq!(names, vec!["Consoles", "Arcade"]);
        assert_eq!(flags, vec![false, false]);
    }

    #[test]
    fn media_is_filtered_case_insensitively_but_other_is_surfaced() {
        let raw = vec![
            "Arcade".to_string(),
            "Other".to_string(),
            "media".to_string(),
            "Consoles".to_string(),
        ];
        let (names, flags) = vc(&raw, &[], false);
        // `media` is dropped; `Other` now passes through (it holds launchables).
        assert_eq!(names, vec!["Arcade", "Other", "Consoles"]);
        assert_eq!(flags, vec![false, false, false]);
    }

    #[test]
    fn empty_raw_yields_empty_visible_list() {
        let (names, flags) = vc(&[], &[], false);
        assert!(names.is_empty());
        assert!(flags.is_empty());
    }

    #[test]
    fn original_casing_is_preserved_for_visible_entries() {
        let raw = vec!["arcade".to_string(), "CONSOLES".to_string()];
        let (names, _) = vc(&raw, &[], false);
        assert_eq!(names, vec!["arcade", "CONSOLES"]);
    }

    #[test]
    fn user_hidden_category_excluded_when_show_hidden_false() {
        let raw = vec!["Arcade".to_string(), "Consoles".to_string()];
        let user_hidden = vec!["Consoles".to_string()];
        let (names, _) = vc(&raw, &user_hidden, false);
        assert_eq!(names, vec!["Arcade"]);
    }

    #[test]
    fn user_hidden_category_shown_with_flag_when_show_hidden_true() {
        let raw = vec!["Arcade".to_string(), "Consoles".to_string()];
        let user_hidden = vec!["Consoles".to_string()];
        let (names, flags) = vc(&raw, &user_hidden, true);
        assert_eq!(names, vec!["Arcade", "Consoles"]);
        assert_eq!(flags, vec![false, true]);
    }

    #[test]
    fn user_hidden_is_case_sensitive() {
        // The category string in user_hidden must match the raw string exactly.
        // A case mismatch does not hide the category.
        let raw = vec!["Consoles".to_string()];
        let user_hidden = vec!["consoles".to_string()];
        let (names, flags) = vc(&raw, &user_hidden, false);
        assert_eq!(names, vec!["Consoles"]);
        assert_eq!(flags, vec![false]);
    }

    #[test]
    fn builtin_hidden_categories_never_user_unhideable() {
        // Even if "Media" somehow ends up in user_hidden (which should never
        // happen since it's never surfaced as a tile), the builtin filter
        // still drops it before we check user_hidden.
        let raw = vec!["Arcade".to_string(), "Media".to_string()];
        let user_hidden = vec!["Media".to_string()];
        let (names_off, _) = vc(&raw, &user_hidden, false);
        let (names_on, flags_on) = vc(&raw, &user_hidden, true);
        // Media is always gone, regardless of show_hidden.
        assert_eq!(names_off, vec!["Arcade"]);
        assert_eq!(names_on, vec!["Arcade"]);
        assert_eq!(flags_on, vec![false]);
    }

    // ----- hide_empty_categories filter (media-based) -----

    #[test]
    fn empty_category_dropped_when_hide_empty_true_and_show_hidden_false() {
        // The dev-zap-63 scenario: Core surfaces Console + Computer +
        // Software (its systemdefs mention them), but this cabinet's
        // media.db only has games under Console — so Computer +
        // Software should drop.
        let raw = vec![
            "Console".to_string(),
            "Computer".to_string(),
            "Software".to_string(),
        ];
        let media = media_set(&["Console"]);
        let (names, flags) = visible_categories(&raw, &media, &[], false, true);
        assert_eq!(names, vec!["Console"]);
        assert_eq!(flags, vec![false]);
    }

    #[test]
    fn empty_category_kept_when_hide_empty_false() {
        // Default posture — upstream behavior — must be unchanged.
        let raw = vec!["Console".to_string(), "Computer".to_string()];
        let media = media_set(&["Console"]);
        let (names, _) = visible_categories(&raw, &media, &[], false, false);
        assert_eq!(names, vec!["Console", "Computer"]);
    }

    #[test]
    fn empty_category_kept_when_show_hidden_true_even_with_hide_empty() {
        // Documented carve-out: show_hidden=true means the user has
        // explicitly asked to see hidden tiles, so an "all hidden"
        // category is not effectively empty from their POV.
        let raw = vec!["Console".to_string(), "Computer".to_string()];
        let media = media_set(&["Console"]);
        let (names, _) = visible_categories(&raw, &media, &[], true, true);
        assert_eq!(names, vec!["Console", "Computer"]);
    }

    #[test]
    fn media_categories_match_is_case_insensitive() {
        // Core sometimes reports category as "console" (lowercase) on
        // media entries when systemdefs declare "Console" — the filter
        // must not drop the tile in that case.
        let raw = vec!["Console".to_string()];
        let media = media_set(&["console"]);
        let (names, _) = visible_categories(&raw, &media, &[], false, true);
        assert_eq!(names, vec!["Console"]);
    }

    #[test]
    fn empty_media_set_is_a_no_op_even_when_hide_empty_true() {
        // Startup race: MediaCategoriesEndpoint hasn't resolved yet.
        // Dropping every category would flash an empty Hub for the
        // fraction of a second until the fetch lands. Skip the filter
        // entirely when the set is empty.
        let raw = vec!["Console".to_string(), "Computer".to_string()];
        let (names, _) = visible_categories(&raw, &HashSet::new(), &[], false, true);
        assert_eq!(names, vec!["Console", "Computer"]);
    }

    #[test]
    fn hide_empty_and_user_hidden_stack_correctly() {
        // "Console" has media but is user-hidden; "Computer" has no
        // media. With hide_empty + show_hidden=false, both drop.
        let raw = vec!["Console".to_string(), "Computer".to_string()];
        let media = media_set(&["Console"]);
        let user_hidden = vec!["Console".to_string()];
        let (names, _) = visible_categories(&raw, &media, &user_hidden, false, true);
        assert!(names.is_empty());
    }

    #[test]
    fn hide_empty_drops_other_when_no_media_in_it() {
        // "Other" gets the same media-set treatment as any category —
        // no special-casing here (the "Other = catch-all" logic lives
        // upstream in CatalogData::systems_by_category).
        let raw = vec!["Console".to_string(), "Other".to_string()];
        let media = media_set(&["Console"]);
        let (names, _) = visible_categories(&raw, &media, &[], false, true);
        assert_eq!(names, vec!["Console"]);
    }
}
