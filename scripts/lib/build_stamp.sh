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

write_build_stamp() {
    local sha branch built
    sha="$(git -C "$PROJECT_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)"
    branch="$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
    built="$(date -u +%Y-%m-%d)"
    if [ -n "$(git -C "$PROJECT_DIR" status --porcelain 2>/dev/null)" ]; then
        sha="${sha}-dirty"   # a pack built off uncommitted edits must say so
    fi
    printf '{"commit": "%s", "branch": "%s", "built": "%s"}\n' \
        "$sha" "$branch" "$built" > "$BUILD_STAMP_FILE"
    log "Build stamp: $sha ($branch, $built)"
}

remove_build_stamp() {
    rm -f "$BUILD_STAMP_FILE" "$BUILD_STAMP_FILE.import" "$BUILD_STAMP_FILE.uid"
}
