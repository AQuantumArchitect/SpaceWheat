#!/usr/bin/env bash
# scripts/lib/build_stamp.sh — the commit identity a pack carries.
#
# Which commit was this pack cut from? Core/Config/BuildInfo.gd reads the stamp
# and the title screen, the Z-dev row, and the bug-report clipboard all show it.
# Written from git rather than typed by hand because the hand-typed half
# (config/version) sat 66 commits stale once already; a stamp nobody types
# cannot go stale.
#
# The stamp exists ONLY inside a pack: written immediately before the export,
# deleted immediately after via a trap, and gitignored. A source run then
# honestly reports "source" instead of claiming the last build's commit (#141).
#
# Shared by every export lane — desktop and web — so a browser build is exactly
# as traceable as a desktop one. Callers must define PROJECT_DIR and provide
# log(), then install the trap themselves:
#
#     source "$SCRIPT_DIR/lib/build_stamp.sh"
#     trap remove_build_stamp EXIT

BUILD_STAMP_FILE="$PROJECT_DIR/Core/Config/build_stamp.json"

# The source identity of a build: the commit, plus — when the tree is dirty — a
# short hash of the uncommitted delta.
#
# A bare "-dirty" suffix was not enough. Three web bundles shipped from this
# repo carrying stamps that could not be told apart, because "dirty" says only
# THAT there were edits, never WHICH. That is not a corner case here: a second
# agent edits this repo concurrently, so building off a dirty tree is the normal
# case, not the exception, and two dirty builds an hour apart are routinely
# different games.
#
# Covers tracked content (status + diff HEAD) and the NAMES of untracked files.
# Edits to the body of an untracked file do not move the hash — an accepted
# limit, since res:// content that ships is tracked.
build_id() {
    local sha delta
    sha="$(git -C "$PROJECT_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)"
    if [ -n "$(git -C "$PROJECT_DIR" status --porcelain 2>/dev/null)" ]; then
        delta="$(
            {
                git -C "$PROJECT_DIR" status --porcelain 2>/dev/null
                git -C "$PROJECT_DIR" diff HEAD 2>/dev/null
            } | sha1sum | cut -c1-6
        )"
        sha="${sha}-dirty.${delta}"
    fi
    printf '%s' "$sha"
}

write_build_stamp() {
    local sha branch built
    sha="$(build_id)"
    branch="$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
    built="$(date -u +%Y-%m-%d)"
    printf '{"commit": "%s", "branch": "%s", "built": "%s"}\n' \
        "$sha" "$branch" "$built" > "$BUILD_STAMP_FILE"
    log "Build stamp: $sha ($branch, $built)"
}

remove_build_stamp() {
    rm -f "$BUILD_STAMP_FILE" "$BUILD_STAMP_FILE.import" "$BUILD_STAMP_FILE.uid"
}
