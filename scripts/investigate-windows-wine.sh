#!/bin/bash
# investigate-windows-wine.sh - Unpack and probe the Windows desktop build under Wine.
#
# This script keeps all runtime state inside the workspace so repeated runs do not
# depend on ad hoc shell commands or approvals. It is meant for iterative debugging.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PACKAGES_DIR="${PACKAGES_DIR:-$PROJECT_DIR/releases/packages}"
ARCHIVE_PATH="${ARCHIVE_PATH:-}"
RUN_SOURCE_DIR="${RUN_SOURCE_DIR:-}"
EXTRACT_ROOT="${EXTRACT_ROOT:-$PROJECT_DIR/.tmp/windows-wine-investigation}"
RUN_DIR="${RUN_DIR:-$EXTRACT_ROOT/run}"
LOG_DIR="${LOG_DIR:-$EXTRACT_ROOT/logs}"
WINE_PREFIX="${WINE_PREFIX:-$EXTRACT_ROOT/prefix}"
WINE_HOME="${WINE_HOME:-$EXTRACT_ROOT/home}"
WINE_RUNTIME_DIR="${WINE_RUNTIME_DIR:-$EXTRACT_ROOT/runtime}"
WINE_BIN="${WINE_BIN:-}"
MODE="${MODE:-headless}"
TIMEOUT_SECS="${TIMEOUT_SECS:-45}"
QUIT_AFTER="${QUIT_AFTER:-60}"
EXE_NAME="${EXE_NAME:-SpaceWheat.exe}"
DLL_NAME="${DLL_NAME:-libquantummatrix.windows.template_release.x86_64.dll}"

source "$SCRIPT_DIR/lib/log.sh"

show_help() {
    cat <<'EOF'
Unpack and probe the Windows SpaceWheat build under Wine.

Usage:
  ./scripts/investigate-windows-wine.sh [OPTIONS]

Options:
  --archive PATH       Zip archive to unpack
  --run-dir PATH       Pre-unzipped Windows folder to run directly
  --packages-dir PATH  Search directory for the latest Windows archive
  --extract-root PATH  Workspace-local extraction and Wine state root
  --mode MODE          headless, play, or both (default: headless)
  --timeout SECS       Timeout for each Wine probe (default: 45)
  --quit-after SECS    Headless quit-after value (default: 60)
  --wine-bin PATH      Wine executable to use
  --help               Show this help

Defaults:
  Archive: latest releases/packages/spacewheat-windows-*.zip
  Run dir: use the provided --run-dir or the extracted archive contents
  Extract root: ./.tmp/windows-wine-investigation

The script can extract the archive into a workspace-local directory or run a
pre-unzipped folder directly. In both cases it runs from the build directory
so you can compare path-sensitive behavior without touching ad hoc shells.
EOF
}

archive_candidates() {
    find "$PACKAGES_DIR" -maxdepth 1 -type f -name 'spacewheat-windows-*.zip' 2>/dev/null | sort
}

extract_archive() {
    local archive="$1"
    local target="$2"

    rm -rf "$target"
    mkdir -p "$target"

    if command -v unzip >/dev/null 2>&1; then
        unzip -q "$archive" -d "$target"
    else
        command -v python3 >/dev/null 2>&1 || error "python3 not found and unzip is unavailable"
        python3 - "$archive" "$target" <<'PY'
import pathlib
import sys
import zipfile

archive = pathlib.Path(sys.argv[1])
target = pathlib.Path(sys.argv[2])

with zipfile.ZipFile(archive, "r") as zf:
    zf.extractall(target)
PY
    fi
}

detect_wine_bin() {
    if [ -n "$WINE_BIN" ]; then
        printf '%s\n' "$WINE_BIN"
        return 0
    fi

    if [ -x /usr/lib/wine/wine64 ]; then
        printf '%s\n' /usr/lib/wine/wine64
        return 0
    fi

    if command -v wine >/dev/null 2>&1; then
        printf '%s\n' "$(command -v wine)"
        return 0
    fi

    error "Wine not found"
}

run_wine() {
    local label="$1"
    local log_file="$2"
    local wine_bin="$3"
    local workdir="$4"
    shift 4

    log "Running ${label}"
    mkdir -p "$LOG_DIR"
    (
        cd "$workdir"
        HOME="$WINE_HOME" \
        WINEPREFIX="$WINE_PREFIX" \
        WINEARCH=win64 \
        XDG_RUNTIME_DIR="$WINE_RUNTIME_DIR" \
            timeout "$TIMEOUT_SECS" "$wine_bin" "$@" >"$log_file" 2>&1
    )
}

mode_enabled() {
    local wanted="$1"
    case "$MODE" in
        both) return 0 ;;
        "$wanted") return 0 ;;
        *) return 1 ;;
    esac
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --archive)
            ARCHIVE_PATH="$2"
            shift 2
            ;;
        --run-dir)
            RUN_SOURCE_DIR="$2"
            shift 2
            ;;
        --packages-dir)
            PACKAGES_DIR="$2"
            shift 2
            ;;
        --extract-root)
            EXTRACT_ROOT="$2"
            shift 2
            ;;
        --mode)
            MODE="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT_SECS="$2"
            shift 2
            ;;
        --quit-after)
            QUIT_AFTER="$2"
            shift 2
            ;;
        --wine-bin)
            WINE_BIN="$2"
            shift 2
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

command -v timeout >/dev/null 2>&1 || error "timeout not found"

if [ -z "$RUN_SOURCE_DIR" ] && [ -z "$ARCHIVE_PATH" ]; then
    mapfile -t archives < <(archive_candidates)
    if [ "${#archives[@]}" -eq 0 ]; then
        error "No Windows package archive found under: $PACKAGES_DIR"
    fi
    ARCHIVE_PATH="${archives[-1]}"
fi

[ -z "$RUN_SOURCE_DIR" ] || [ -d "$RUN_SOURCE_DIR" ] || error "Run dir not found: $RUN_SOURCE_DIR"
[ -f "$ARCHIVE_PATH" ] || [ -z "$ARCHIVE_PATH" ] || error "Archive not found: $ARCHIVE_PATH"

WINE_BIN="$(detect_wine_bin)"

mkdir -p "$EXTRACT_ROOT" "$LOG_DIR" "$WINE_HOME" "$WINE_RUNTIME_DIR"

if [ -n "$RUN_SOURCE_DIR" ]; then
    log "Using pre-unzipped run directory"
    RUN_DIR="$RUN_SOURCE_DIR"
else
    log "Preparing workspace-local extraction"
    extract_archive "$ARCHIVE_PATH" "$RUN_DIR"
fi

[ -f "$RUN_DIR/$EXE_NAME" ] || error "Missing Windows exe after extraction: $RUN_DIR/$EXE_NAME"
[ -f "$RUN_DIR/$DLL_NAME" ] || error "Missing native DLL after extraction: $RUN_DIR/$DLL_NAME"

if [ -n "$RUN_SOURCE_DIR" ]; then
    success "Run dir source: $RUN_SOURCE_DIR"
else
    success "Archive unpacked: $ARCHIVE_PATH"
fi
success "Run dir: $RUN_DIR"
success "Wine binary: $WINE_BIN"

if mode_enabled headless; then
    HEADLESS_LOG="$LOG_DIR/headless.log"
    if run_wine "headless probe" "$HEADLESS_LOG" "$WINE_BIN" "$RUN_DIR" "./$EXE_NAME" --headless --rendering-driver opengl3 --audio-driver Dummy --quit-after "$QUIT_AFTER"; then
        success "Headless probe completed"
    else
        status=$?
        warn "Headless probe exited with status $status"
    fi
    echo "headless_log=$HEADLESS_LOG"
    tail -n 80 "$HEADLESS_LOG" || true
fi

if mode_enabled play; then
    PLAY_LOG="$LOG_DIR/play.log"
    if run_wine "interactive launch" "$PLAY_LOG" "$WINE_BIN" "$RUN_DIR" "./$EXE_NAME"; then
        success "Interactive launch completed"
    else
        status=$?
        warn "Interactive launch exited with status $status"
    fi
    echo "play_log=$PLAY_LOG"
    tail -n 80 "$PLAY_LOG" || true
fi

echo ""
echo "Artifacts:"
echo "  Archive: $ARCHIVE_PATH"
echo "  Run dir: $RUN_DIR"
echo "  Logs:    $LOG_DIR"
