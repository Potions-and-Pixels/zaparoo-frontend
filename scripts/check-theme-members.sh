#!/usr/bin/env bash
# Zaparoo Frontend
# Copyright (c) 2026 Wizzo Pty Ltd and the Zaparoo Project contributors.
# SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0
#
# Fails when QML reads a member of the Sizing / Theme / Motion singletons that
# the singleton does not declare (e.g. `Sizing.cornerRadius` after an upstream
# rename). qmllint only reports that as a `missing-property` *warning*, and
# that category can't be made an error repo-wide because delegate-typed reads
# (PagedGrid's `cellIndex` on QQuickItem etc.) legitimately trip it. At
# runtime the binding just evaluates to `undefined` and the property keeps its
# default — a silent regression (square corners, zero sizes) rather than a
# crash, which is exactly how it slipped through the v1.3.1 merge.
#
# Pure coreutils + grep/sed, no Qt or build needed, like check-baked-icons.sh.
# Heuristic on purpose: a `//` line comment is stripped before scanning so
# prose mentioning an old member name doesn't trip it.
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd -- "$script_dir/.." && pwd -P)"
theme_dir="$repo_root/src/ui/theme"

status=0
for singleton in Sizing Theme Motion; do
    def="$theme_dir/$singleton.qml"
    [[ -f "$def" ]] || { echo "Missing $def" >&2; exit 1; }

    declared="$(mktemp)"
    used="$(mktemp)"
    trap 'rm -f "$declared" "$used"' EXIT

    # Declared members: properties (incl. readonly/required/default/alias),
    # functions and signals, plus QtObject's own objectName.
    {
        sed -nE 's/^[[:space:]]*((readonly|required|default)[[:space:]]+)*property[[:space:]]+[^[:space:]]+[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\3/p' "$def"
        sed -nE 's/^[[:space:]]*function[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\1/p' "$def"
        sed -nE 's/^[[:space:]]*signal[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\1/p' "$def"
        echo objectName
    } | sort -u >"$declared"

    # Used members, as `file:line:member`, across app + test QML.
    (cd "$repo_root" && find src/ui tests -name '*.qml' -not -path '*/translations/*' | sort) |
        while IFS= read -r file; do
            sed -E 's#(^|[^:])//.*$#\1#' "$repo_root/$file" |
                grep -noE "(^|[^A-Za-z0-9_.])$singleton\.[A-Za-z_][A-Za-z0-9_]*" |
                sed -E "s#^([0-9]+):.*$singleton\.([A-Za-z0-9_]+)\$#$file:\1:\2#" || true
        done >"$used"

    while IFS=: read -r file line member; do
        if ! grep -qxF "$member" "$declared"; then
            echo "$file:$line: $singleton.$member is not declared in src/ui/theme/$singleton.qml" >&2
            status=1
        fi
    done <"$used"
    rm -f "$declared" "$used"
    trap - EXIT
done

if [[ "$status" -ne 0 ]]; then
    echo "Undeclared theme-singleton members found (see above)." >&2
fi
exit "$status"
