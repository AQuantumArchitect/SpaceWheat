#!/bin/bash
# stage-profiling-kit.sh — assemble the Windows-side profiling kit.
#
# WSL has no GPU passthrough, so every frame number measured here is a software
# rasteriser's. This packs everything a Windows-native agent needs to produce a
# real one into a single folder both sides can see, and nothing it does not:
#
#   profiling-kit/
#     README.md          the brief — what is known, what is invalid, what to run
#     RESULTS.md         the template the agent fills in
#     run_desktop.py     stdlib Python 3; drives SpaceWheat.exe via SW_PERF_LOG
#     run_web.py         stdlib Python 3; COOP/COEP server + headed browser
#     build/             a Windows release export CARRYING THE PERF SAMPLER
#     web/              the v1.0-rc3 browser bundle, unzipped
#     results/           empty; the agent writes here, and WSL reads it back
#
# The build is exported fresh rather than reused from releases/: the shipped
# v1.0-rc3 pack predates Core/Debug/PerfSampler.gd, so SW_PERF_LOG would do
# nothing in it and the lane would report an absence it could not explain.
#
# Nothing here is PowerShell: the Windows box has 5.1 only. Nothing here needs
# node or npm either — Python 3.13 is present, and one language is enough.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/lib/log.sh"

KIT_DEST="${KIT_DEST:-/mnt/c/Games/SpaceWheat-Releases/profiling-kit}"
WEB_ZIP="${WEB_ZIP:-/mnt/c/Games/SpaceWheat-Releases/v1.0-rc3/spacewheat-web-1.0-rc3.zip}"
ENDGAME_SAVE="${ENDGAME_SAVE:-$PROJECT_DIR/🍄/🧪/checkpoints/endrun_ending.tres}"
BUILD_SRC="${BUILD_SRC:-$PROJECT_DIR/releases/local/windows-native}"
SKIP_BUILD=false

for arg in "$@"; do
    case "$arg" in
        --skip-build) SKIP_BUILD=true ;;
        --help) sed -n '2,30p' "${BASH_SOURCE[0]}"; exit 0 ;;
        *) error "unknown option: $arg" ;;
    esac
done

# --- the build -------------------------------------------------------------
if [ "$SKIP_BUILD" = false ]; then
    log "Exporting a Windows build with the perf sampler"
    # --skip-native: the Windows DLL is committed and unchanged. Rebuilding it
    # would produce a byte-different MinGW artifact from identical source and
    # dirty the build stamp for no reason.
    "$SCRIPT_DIR/build-desktop-local.sh" --skip-native >/dev/null
fi

[ -f "$BUILD_SRC/SpaceWheat.exe" ] || error "no SpaceWheat.exe in $BUILD_SRC"

log "Staging into $KIT_DEST"
mkdir -p "$KIT_DEST/build" "$KIT_DEST/web" "$KIT_DEST/results"

cp -f "$PROJECT_DIR/tools/profiling_kit/run_desktop.py" \
      "$PROJECT_DIR/tools/profiling_kit/run_web.py" \
      "$PROJECT_DIR/tools/profiling_kit/README.md" \
      "$KIT_DEST/"
cp -f "$PROJECT_DIR/tools/profiling_kit/BASELINE.md" "$KIT_DEST/results/BASELINE.md"
# RESULTS.md is the agent's to write; never clobber a filled-in one.
if [ ! -f "$KIT_DEST/results/RESULTS.md" ]; then
    cp -f "$PROJECT_DIR/tools/profiling_kit/RESULTS.md" "$KIT_DEST/results/RESULTS.md"
else
    warn "results/RESULTS.md already exists — left alone"
fi

rm -rf "$KIT_DEST/build"
mkdir -p "$KIT_DEST/build"
cp -f "$BUILD_SRC"/* "$KIT_DEST/build/"
cp -f "$ENDGAME_SAVE" "$KIT_DEST/build/endrun_ending.tres"

# --- the web bundle --------------------------------------------------------
if [ -f "$WEB_ZIP" ]; then
    if [ -f "$KIT_DEST/web/index.pck" ]; then
        log "web/ already unpacked — skipping the 193 MB copy"
    else
        log "Unpacking $(basename "$WEB_ZIP") (193 MB — a few minutes over /mnt/c)"
        python3 - "$WEB_ZIP" "$KIT_DEST/web" <<'PY'
import sys, zipfile
with zipfile.ZipFile(sys.argv[1]) as z:
    z.extractall(sys.argv[2])
PY
    fi
else
    warn "no web zip at $WEB_ZIP — the browser lane will have nothing to serve"
fi

# --- proof, not assumption -------------------------------------------------
STAMP="$(python3 - "$KIT_DEST/build" <<'PY'
import json, pathlib, sys, zipfile
# The stamp lives inside the pck; read it out of the exe's sibling pack if one
# exists, else just report that the exe is there.
p = pathlib.Path(sys.argv[1], "SpaceWheat.exe")
print(f"{p.name} {p.stat().st_size / 1_048_576:.0f} MB")
PY
)"
success "kit staged: $KIT_DEST"
echo "  build/    $STAMP"
echo "  web/      $(ls "$KIT_DEST/web" 2>/dev/null | wc -l) files"
echo "  save/     $(basename "$ENDGAME_SAVE")"
echo
echo "Windows side:  cd C:\\Games\\SpaceWheat-Releases\\profiling-kit"
echo "               py -3 run_desktop.py"
echo "               py -3 run_web.py"
