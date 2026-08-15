#!/bin/bash
# package-web-build.sh - Package an exported web build for redistribution.
#
# WHY THIS EXISTS
#
# The desktop lane has had a packaging authority since the alpha:
# package-desktop-builds.sh derives its archive name from config/version, and
# tests/test_build_identity.py pins that derivation so a zip can never be named
# something the game inside does not claim.
#
# The web lane had nothing. Its archive was named by hand, every time. So three
# materially different browser bundles — the broken alpha, the emsdk-pinned
# rebuild, and the async-lookahead rebuild — all shipped as
# "spacewheat-web-0.1.0-alpha.zip", each silently overwriting the last. Nothing
# outside the zip could tell them apart: not the filename, not itch's upload
# list, not the release folder. A version number that never moves is not
# versioning, it is decoration.
#
# So the name is derived from two things nobody types:
#   - config/version from project.godot   (the release name, same as desktop)
#   - build_id() from lib/build_stamp.sh  (commit, + delta hash when dirty)
#
# and the script REFUSES to overwrite an existing archive. Cutting the same
# bundle twice is fine; silently replacing a shipped one is the defect.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/lib/log.sh"
source "$SCRIPT_DIR/lib/build_stamp.sh"

EXPORT_DIR="${EXPORT_DIR:-$PROJECT_DIR/releases/web}"
PACKAGE_ROOT="${PACKAGE_ROOT:-$PROJECT_DIR/releases/packages}"
FORCE=false

PROJECT_VERSION="$(grep -oP '^config/version="\K[^"]+' "$PROJECT_DIR/project.godot" 2>/dev/null || true)"
VERSION_TAG="${VERSION_TAG:-${PROJECT_VERSION:-dev}}"

show_help() {
    cat << 'EOF'
Package an exported web build into a distributable zip.

Usage:
  ./scripts/package-web-build.sh [OPTIONS]

Options:
  --export-dir PATH     Exported web bundle (default: ./releases/web)
  --package-root PATH   Archive output root (default: ./releases/packages)
  --version TAG         Version label (default: config/version from project.godot)
  --force               Overwrite an archive of the same name (default: refuse)
  --help                Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --export-dir)   EXPORT_DIR="$2"; shift 2 ;;
        --package-root) PACKAGE_ROOT="$2"; shift 2 ;;
        --version)      VERSION_TAG="$2"; shift 2 ;;
        --force)        FORCE=true; shift ;;
        --help|-h)      show_help; exit 0 ;;
        *)              error "Unknown option: $1" ;;
    esac
done

[ -d "$EXPORT_DIR" ] || error "Missing web export folder: $EXPORT_DIR"
command -v python3 >/dev/null 2>&1 || error "python3 not found"

# A web bundle that is missing any of these boots into a black screen or dies at
# the first farm — both shipped to players once already, so they are gate items
# and not warnings.
[ -f "$EXPORT_DIR/index.html" ] || error "No index.html in $EXPORT_DIR — nothing was exported"
[ -f "$EXPORT_DIR/index.pck" ] || error "No index.pck in $EXPORT_DIR — the export did not finish"
[ -f "$EXPORT_DIR/libquantummatrix.wasm" ] || \
    error "No libquantummatrix.wasm in $EXPORT_DIR — the native extension never made it into the bundle, so the game will load and then abort the first time a farm boots"

# Godot's stock shell fails SILENTLY when the host does not send COOP/COEP: it
# leaves #status at visibility:hidden and the canvas at 300x150, which is the
# black screen three people reported. If the custom shell is not in the export,
# the preset lost html/custom_html_shell and we are about to ship that again.
grep -q "SpaceWheat could not start in this browser" "$EXPORT_DIR/index.html" || \
    error "index.html is not the SpaceWheat shell — check html/custom_html_shell in export_presets.cfg.\nThe stock Godot shell shows a black screen with no message when the host omits COOP/COEP."

# Twemoji is CC-BY 4.0 and attribution is its one condition; it has to travel
# inside the artifact, not merely exist in the repo.
for legal in LICENSE THIRD_PARTY_NOTICES.md; do
    [ -f "$PROJECT_DIR/$legal" ] || error "Missing $legal — refusing to package an archive without its licence"
    cp "$PROJECT_DIR/$legal" "$EXPORT_DIR/$legal"
done

BUILD_ID="$(build_id | tr '.' '-')"
mkdir -p "$PACKAGE_ROOT"
ARCHIVE="$PACKAGE_ROOT/spacewheat-web-${VERSION_TAG}-${BUILD_ID}.zip"

if [ -e "$ARCHIVE" ] && [ "$FORCE" != true ]; then
    error "Refusing to overwrite $(basename "$ARCHIVE").\nThat name is already taken by a packaged build. If the bundle really changed, the build id would have changed with it; if it did not, ship the archive that is already there. Use --force only when you mean to discard the existing one."
fi

log "Packaging web build  ($VERSION_TAG · $BUILD_ID)"
rm -f "$ARCHIVE"
python3 - "$EXPORT_DIR" "$ARCHIVE" <<'PY'
import pathlib
import sys
import zipfile

source = pathlib.Path(sys.argv[1])
target = pathlib.Path(sys.argv[2])

# .import/.uid are Godot editor metadata regenerated on demand. They are not
# runtime files; a browser never reads them.
SKIP_SUFFIXES = (".import", ".uid")

with zipfile.ZipFile(target, "w", compression=zipfile.ZIP_DEFLATED) as zf:
    for path in sorted(source.rglob("*")):
        if path.is_file() and not path.name.endswith(SKIP_SUFFIXES):
            zf.write(path, path.relative_to(source))
PY

log "Web archive: $ARCHIVE"
log "  size: $(stat -c%s "$ARCHIVE") bytes"
log ""
log "Upload this to itch as the HTML5 build. The project's embed options must"
log "have SharedArrayBuffer support ticked, or a threaded Godot export cannot"
log "start — the shell will say so rather than going black."
