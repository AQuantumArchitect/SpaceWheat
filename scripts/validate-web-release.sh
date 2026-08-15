#!/bin/bash
# validate-web-release.sh - Build, gate, and package the browser release.
#
# WHY THIS EXISTS
#
# The desktop lane has had an orchestrator since the alpha:
# validate-desktop-release.sh runs build → smoke → profile → package as one
# command, so a desktop cut is a thing you *run*, not a sequence you remember.
#
# The web lane had all the same pieces — a builder, a link test, a two-load
# browser gate, a play smoke, a packager — and no orchestrator. Every browser
# release was therefore assembled by hand from memory, and what got skipped was
# invisible afterwards. That is how three different bundles shipped under one
# name, and how a bundle went out whose loader had never been opened without
# COOP/COEP headers.
#
# Same shape as the desktop lane, same flags, same report root.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/lib/log.sh"
source "$SCRIPT_DIR/lib/build_stamp.sh"
source "$SCRIPT_DIR/lib/release_paths.sh"

OUTPUT_ROOT="$(sw_web_export_root)"
PACKAGE_ROOT="$(sw_package_root)"
REPORT_ROOT="$(sw_report_root)"
VERSION_TAG="${VERSION_TAG:-$(sw_project_version)}"
VERSION_EXPLICIT=false

DO_BUILD=true
DO_LINK=true
DO_GATE=true
DO_SMOKE=true
DO_PACKAGE=true
BUILD_NATIVE=true

show_help() {
    cat << 'EOF'
Validate and package the SpaceWheat browser release from the current checkout.

Usage:
  ./scripts/validate-web-release.sh [OPTIONS]

Options:
  --output-root PATH    Web export root (default: ./releases/web-local)
  --package-root PATH   Archive output root (default: ./releases/packages)
  --report-root PATH    Gate log root (default: ./releases/validation)
  --version TAG         Package version tag (default: config/version from
                        project.godot — overriding it reintroduces name/stamp
                        drift; don't, unless renaming on purpose)
  --skip-native         Reuse the existing web WASM extension
  --skip-build          Reuse the existing export
  --skip-link           Skip the wasm import/export link test
  --skip-gate           Skip the two-load browser gate (needs playwright-core)
  --skip-smoke          Skip the deep-play browser smoke
  --skip-package        Stop before packaging
  --help                Show this help

Stages:
  1. build    scripts/build-web-local.sh
  2. link     tests/test_web_extension_links.py — every wasm import resolves.
              Catches the emsdk/libc++ mismatch that loads fine and then dies
              at the first call into an unresolved stub.
  3. gate     scripts/gate-web-bundle.mjs — loads the bundle in a real browser
              WITH and WITHOUT cross-origin isolation headers. The headers-absent
              load is the one that matters: itch does not send them unless
              SharedArrayBuffer support is ticked, and the page must SAY it
              cannot run rather than going black.
  4. smoke    scripts/smoke-test-web-export.mjs — boots and plays.
  5. package  scripts/package-web-build.sh — name derived, never typed.

Outputs:
  - export   under ./releases/web-local
  - archive  under ./releases/packages
  - logs     under ./releases/validation/<timestamp>/web/
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output-root)  OUTPUT_ROOT="$2"; shift 2 ;;
        --package-root) PACKAGE_ROOT="$2"; shift 2 ;;
        --report-root)  REPORT_ROOT="$2"; shift 2 ;;
        --version)      VERSION_TAG="$2"; VERSION_EXPLICIT=true; shift 2 ;;
        --skip-native)  BUILD_NATIVE=false; shift ;;
        --skip-build)   DO_BUILD=false; shift ;;
        --skip-link)    DO_LINK=false; shift ;;
        --skip-gate)    DO_GATE=false; shift ;;
        --skip-smoke)   DO_SMOKE=false; shift ;;
        --skip-package) DO_PACKAGE=false; shift ;;
        --help|-h)      show_help; exit 0 ;;
        *)              error "Unknown option: $1" ;;
    esac
done

TIMESTAMP="${SW_RUN_TIMESTAMP:-$(date +%Y%m%d_%H%M%S)}"
RUN_DIR="$REPORT_ROOT/$TIMESTAMP/web"
mkdir -p "$RUN_DIR"

log "Web release validation"
echo "export root:   $OUTPUT_ROOT"
echo "package root:  $PACKAGE_ROOT"
echo "gate logs:     $RUN_DIR"
echo "version:       $VERSION_TAG"

# Recorded before the export reads a single file; checked again after. An
# artifact assembled while the tree moved under it has no honest build id.
sw_capture_source_id
SOURCE_ID="$SW_SOURCE_ID_AT_START"
echo "source id:     $SOURCE_ID"

if [ "$DO_BUILD" = true ]; then
    log "Building web export"
    BUILD_ARGS=(--output-root "$OUTPUT_ROOT")
    [ "$BUILD_NATIVE" = true ] || BUILD_ARGS+=(--skip-native)
    "$PROJECT_DIR/scripts/build-web-local.sh" "${BUILD_ARGS[@]}" 2>&1 | tee "$RUN_DIR/build.log"
    sw_assert_source_unchanged
    success "Web export built"
else
    warn "Skipping build"
fi

[ -f "$OUTPUT_ROOT/index.html" ] || error "No export at $OUTPUT_ROOT — run without --skip-build"

if [ "$DO_LINK" = true ]; then
    # Checks native/bin/web/libquantummatrix.wasm against the engine's export
    # templates — the extension that is about to go INTO the bundle, not the
    # bundle itself. That is the right place: an unresolved import is baked in
    # at compile time, so catching it before the export saves the export.
    log "Checking wasm link closure"
    ( cd "$PROJECT_DIR" && python3 -m pytest tests/test_web_extension_links.py -q ) \
        2>&1 | tee "$RUN_DIR/link.log"
    success "Every wasm import resolves"
else
    warn "Skipping link test"
fi

if [ "$DO_GATE" = true ]; then
    log "Browser gate (with AND without isolation headers)"
    if node -e "import('playwright-core')" >/dev/null 2>&1; then
        node "$SCRIPT_DIR/gate-web-bundle.mjs" "$OUTPUT_ROOT" 2>&1 | tee "$RUN_DIR/gate.log"
        success "Bundle boots isolated, and speaks when it is not"
    else
        error "playwright-core is not installed, so the browser gate cannot run.
This is the gate that catches a silently-black page — the exact failure that
shipped in 0.1.0-alpha. Install it, or pass --skip-gate to ship ungated on
purpose and say so in the release notes."
    fi
else
    warn "Skipping browser gate — the headers-absent case is UNVERIFIED"
fi

if [ "$DO_SMOKE" = true ]; then
    log "Deep-play smoke"
    node "$SCRIPT_DIR/smoke-test-web-export.mjs" "$OUTPUT_ROOT" \
        --report "$RUN_DIR/smoke-report.json" 2>&1 | tee "$RUN_DIR/smoke.log"
    success "Bundle boots and plays"
else
    warn "Skipping play smoke"
fi

if [ "$DO_PACKAGE" = true ]; then
    sw_assert_source_unchanged
    log "Packaging web build"
    PACKAGE_ARGS=(--export-dir "$OUTPUT_ROOT" --package-root "$PACKAGE_ROOT")
    if [ "$VERSION_EXPLICIT" = true ]; then
        PACKAGE_ARGS+=(--version "$VERSION_TAG")
    fi
    "$PROJECT_DIR/scripts/package-web-build.sh" "${PACKAGE_ARGS[@]}" 2>&1 | tee "$RUN_DIR/package.log"
    success "Web archive created"
else
    warn "Skipping package step"
fi

echo ""
echo "Web validation complete:"
echo "  export:   $OUTPUT_ROOT"
echo "  logs:     $RUN_DIR"
[ "$DO_PACKAGE" = true ] && echo "  packages: $PACKAGE_ROOT"
exit 0
