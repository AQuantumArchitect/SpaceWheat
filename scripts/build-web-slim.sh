#!/bin/bash
# build-web-slim.sh — the Web-Slim build (GitHub Pages), same as CI.
#
# Exports preset "Web-Slim": no music, no raster art (SVG only), the
# NON-threaded engine + native/bin/web/libquantummatrix.nothreads.wasm, so it
# needs no COOP/COEP headers. Custom feature "slim" tells MusicManager the
# music is absent. .github/workflows/pages-slim.yml runs the same export on
# every PR (build only) and deploys it from main.
#
# Usage: ./scripts/build-web-slim.sh [--output-root DIR] [--godot-bin PATH]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT4:-${SW_GODOT_BIN:-godot}}"
OUT="$ROOT/build/web-slim"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --output-root) OUT="$2"; shift 2 ;;
        --godot-bin) GODOT="$2"; shift 2 ;;
        -h|--help) sed -n 2,10p "$0"; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
done
command -v "$GODOT" >/dev/null 2>&1 || { echo "Godot not found: $GODOT (set GODOT4)" >&2; exit 1; }
[ -f "$ROOT/native/bin/web/libquantummatrix.nothreads.wasm" ] || { echo "missing native/bin/web/libquantummatrix.nothreads.wasm" >&2; exit 1; }
rm -rf "$OUT"; mkdir -p "$OUT"
"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1 || true
"$GODOT" --headless --path "$ROOT" --export-release "Web-Slim" "$OUT/index.html"
for f in index.html index.pck index.wasm libquantummatrix.nothreads.wasm; do
    [ -f "$OUT/$f" ] || { echo "Web-Slim export is missing $f" >&2; exit 1; }
done
touch "$OUT/.nojekyll"
big=$(find "$OUT" -type f -size +95M)
[ -z "$big" ] || { echo "files over 95 MB (GitHub limit 100 MB): $big" >&2; exit 1; }
echo "OK: $(du -sh "$OUT" | cut -f1) in $OUT"
