#!/bin/bash
# build-web-pages.sh — the GitHub Pages "lite" web build.
#
# Exports preset "Web Pages (lite)" (export_presets.cfg): the Web build minus
# music and raster art (emoji SVGs stay), tagged with the pages_lite feature
# so MusicManager and the title screen know those assets are absent. Uses the
# committed native/bin/web/libquantummatrix.wasm (no native rebuild).
#
# GitHub Pages cannot send COOP/COEP headers; the preset turns on Godot's PWA
# service worker (ensure_cross_origin_isolation_headers), which supplies them
# after a one-time reload so the threaded engine + native wasm can run.
#
# Usage: ./scripts/build-web-pages.sh [--output-root DIR] [--godot-bin PATH]
# Output: <output-root>/index.html (+ .pck/.wasm/.js, service worker, .nojekyll)
set -euo pipefail
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
GODOT_BIN="${SW_GODOT_BIN:-${GODOT_BIN:-godot}}"
OUTPUT_ROOT="$PROJECT_DIR/exports/pages"
PRESET="Web Pages (lite)"
MAX_FILE_MB=95   # GitHub rejects files over 100 MB

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output-root) OUTPUT_ROOT="$2"; shift 2 ;;
        --godot-bin) GODOT_BIN="$2"; shift 2 ;;
        -h|--help) sed -n 2,16p "$0"; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
done

command -v "$GODOT_BIN" >/dev/null 2>&1 || { echo "Godot not found: $GODOT_BIN" >&2; exit 1; }
[ -f "$PROJECT_DIR/native/bin/web/libquantummatrix.wasm" ] || { echo "missing native/bin/web/libquantummatrix.wasm" >&2; exit 1; }

TMP="${GODOT_TMP_ROOT:-/tmp/spacewheat-godot-pages-export}"
mkdir -p "$TMP/runtime" "$TMP/config" "$TMP/cache"
godot_headless() {
    env XDG_RUNTIME_DIR="$TMP/runtime" XDG_CACHE_HOME="$TMP/cache" \
        "$GODOT_BIN" --headless --audio-driver Dummy --path "$PROJECT_DIR" "$@"
}

rm -rf "$OUTPUT_ROOT"
mkdir -p "$OUTPUT_ROOT"
echo "== import"
godot_headless --import >/dev/null 2>&1 || true
echo "== export: $PRESET -> $OUTPUT_ROOT/index.html"
godot_headless --export-release "$PRESET" "$OUTPUT_ROOT/index.html" 2>&1 | grep -E "ERROR|error|Export" | tail -20 || true
[ -f "$OUTPUT_ROOT/index.html" ] || { echo "export produced no index.html" >&2; exit 1; }
[ -f "$OUTPUT_ROOT/index.pck" ] || { echo "export produced no index.pck" >&2; exit 1; }

# Pages serves through Jekyll unless told not to; Godot's files need no processing.
touch "$OUTPUT_ROOT/.nojekyll"

echo "== bundle"
du -h "$OUTPUT_ROOT"/* | sort -rh
big=$(find "$OUTPUT_ROOT" -type f -size +"${MAX_FILE_MB}"M)
if [ -n "$big" ]; then
    echo "files over ${MAX_FILE_MB} MB (GitHub limit is 100 MB):" >&2; echo "$big" >&2; exit 1
fi
echo "OK: $(du -sh "$OUTPUT_ROOT" | cut -f1) in $OUTPUT_ROOT"
