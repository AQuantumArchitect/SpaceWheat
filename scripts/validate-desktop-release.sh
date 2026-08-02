#!/bin/bash
# validate-desktop-release.sh - Build, smoke-test, profile, and package desktop releases
#
# This is the grounded local release gate for the current desktop shipping path.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

OUTPUT_ROOT="${OUTPUT_ROOT:-$PROJECT_DIR/releases/local}"
PACKAGE_ROOT="${PACKAGE_ROOT:-$PROJECT_DIR/releases/packages}"
REPORT_ROOT="${REPORT_ROOT:-$PROJECT_DIR/releases/validation}"
VERSION_TAG="${VERSION_TAG:-dev}"
WINDOWS_SMOKE_MODE="${WINDOWS_SMOKE_MODE:-skip}"
STRICT_WINDOWS_PROFILE="${STRICT_WINDOWS_PROFILE:-0}"

DO_BUILD=true
DO_SMOKE=true
DO_PROFILE=true
DO_PACKAGE=true

source "$SCRIPT_DIR/lib/log.sh"

show_help() {
    cat << 'EOF'
Validate SpaceWheat desktop releases from the current checkout.

Usage:
  ./scripts/validate-desktop-release.sh [OPTIONS]

Options:
  --output-root PATH         Export root (default: ./releases/local)
  --package-root PATH        Package root (default: ./releases/packages)
  --report-root PATH         Validation report root (default: ./releases/validation)
  --version TAG              Package version tag (default: dev)
  --windows-smoke-mode MODE  skip|native (default: skip)
  --skip-build               Reuse existing exports
  --skip-smoke               Skip export smoke tests
  --skip-profile             Skip runtime profiling
  --skip-package             Skip archive packaging
  --help                     Show this help

Environment:
  GODOT_BIN                  Passed through to build/export scripts
  WINDOWS_SMOKE_MODE         Native Windows export smoke mode for WSL interop
  STRICT_WINDOWS_PROFILE     Set to 1 to fail validation when Windows profiling fails

Outputs:
  - local exports under ./releases/local
  - packages under ./releases/packages
  - validation logs and JSON profiles under ./releases/validation/<timestamp>/
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output-root)
            OUTPUT_ROOT="$2"
            shift 2
            ;;
        --package-root)
            PACKAGE_ROOT="$2"
            shift 2
            ;;
        --report-root)
            REPORT_ROOT="$2"
            shift 2
            ;;
        --version)
            VERSION_TAG="$2"
            shift 2
            ;;
        --windows-smoke-mode)
            WINDOWS_SMOKE_MODE="$2"
            shift 2
            ;;
        --skip-build)
            DO_BUILD=false
            shift
            ;;
        --skip-smoke)
            DO_SMOKE=false
            shift
            ;;
        --skip-profile)
            DO_PROFILE=false
            shift
            ;;
        --skip-package)
            DO_PACKAGE=false
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

case "$WINDOWS_SMOKE_MODE" in
    skip|native) ;;
    *)
        error "Unknown windows smoke mode: $WINDOWS_SMOKE_MODE (use skip or native)"
        ;;
esac

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
RUN_DIR="$REPORT_ROOT/$TIMESTAMP"
SMOKE_LOG_DIR="$RUN_DIR/smoke"
PROFILE_DIR="$RUN_DIR/profiles"

mkdir -p "$RUN_DIR" "$SMOKE_LOG_DIR" "$PROFILE_DIR"

log "Desktop release validation"
echo "output root:         $OUTPUT_ROOT"
echo "package root:        $PACKAGE_ROOT"
echo "validation reports:  $RUN_DIR"
echo "windows smoke mode:  $WINDOWS_SMOKE_MODE"

if [ "$DO_BUILD" = true ]; then
    log "Building desktop exports"
    "$PROJECT_DIR/scripts/build-desktop-local.sh" --output-root "$OUTPUT_ROOT"
    success "Desktop exports built"
else
    warn "Skipping build"
fi

if [ "$DO_SMOKE" = true ]; then
    log "Running desktop export smoke tests"
    LOG_DIR="$SMOKE_LOG_DIR" \
    WINDOWS_SMOKE_MODE="$WINDOWS_SMOKE_MODE" \
        "$PROJECT_DIR/scripts/smoke-test-desktop-export.sh" "$OUTPUT_ROOT"
    success "Smoke tests passed"
else
    warn "Skipping smoke tests"
fi

if [ "$DO_PROFILE" = true ]; then
    log "Profiling exported Linux bundle"
    "$PROJECT_DIR/scripts/profile-export-runtime.sh" \
        "$OUTPUT_ROOT/linux-native" \
        "$PROFILE_DIR/linux"
    success "Linux export profile complete"

    if command -v cmd.exe >/dev/null 2>&1; then
        log "Profiling exported Windows bundle"
        if "$PROJECT_DIR/scripts/profile-export-runtime.sh" \
            "$OUTPUT_ROOT/windows-native" \
            "$PROFILE_DIR/windows"; then
            success "Windows export profile complete"
        elif [ "$STRICT_WINDOWS_PROFILE" = "1" ]; then
            error "Windows export profiling failed"
        else
            warn "Windows export profiling failed in this environment; keeping Linux validation results"
        fi
    else
        warn "Skipping Windows export profiling (cmd.exe unavailable)"
    fi
else
    warn "Skipping runtime profiling"
fi

if [ "$DO_PACKAGE" = true ]; then
    log "Packaging desktop exports"
    "$PROJECT_DIR/scripts/package-desktop-builds.sh" \
        --output-root "$OUTPUT_ROOT" \
        --package-root "$PACKAGE_ROOT" \
        --version "$VERSION_TAG"
    success "Packages created"
else
    warn "Skipping package step"
fi

echo ""
echo "Validation complete:"
echo "  reports:  $RUN_DIR"
echo "  exports:  $OUTPUT_ROOT"
if [ "$DO_PACKAGE" = true ]; then
    echo "  packages: $PACKAGE_ROOT"
fi
