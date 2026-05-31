#!/bin/bash
# smoke-test-desktop-export.sh - Verify exported desktop bundles are structurally sound.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source "$PROJECT_DIR/scripts/lib/godot_runtime_env.sh"
EXPORT_ROOT="${1:-$PROJECT_DIR/releases/local}"
WINDOWS_DIR="$EXPORT_ROOT/windows-native"
LINUX_DIR="$EXPORT_ROOT/linux-native"
LOG_DIR="${LOG_DIR:-/tmp/spacewheat-export-smoke}"
GODOT_EXPORT_CONFIG_HOME="${GODOT_EXPORT_CONFIG_HOME:-$PROJECT_DIR/.build/xdg-config}"
SMOKE_HOME="${SMOKE_HOME:-/tmp/spacewheat-smoke-home}"
WINDOWS_SMOKE_MODE="${WINDOWS_SMOKE_MODE:-skip}"

log() { echo -e "\n\033[1;34m▶ $1\033[0m"; }
success() { echo -e "\033[1;32m✓ $1\033[0m"; }
error() { echo -e "\033[1;31m✗ $1\033[0m" >&2; exit 1; }

[ -x "$LINUX_DIR/SpaceWheat.x86_64" ] || error "Missing Linux export executable: $LINUX_DIR/SpaceWheat.x86_64"
[ -f "$LINUX_DIR/libquantummatrix.linux.template_release.x86_64.so" ] || error "Missing Linux native library"
[ -f "$WINDOWS_DIR/SpaceWheat.exe" ] || error "Missing Windows export executable"
[ -f "$WINDOWS_DIR/libquantummatrix.windows.template_release.x86_64.dll" ] || error "Missing Windows native DLL"

mkdir -p "$LOG_DIR" "$GODOT_EXPORT_CONFIG_HOME"
mkdir -p "$SMOKE_HOME"
LINUX_LOG="$LOG_DIR/linux-export.log"
WINDOWS_LOG="$LOG_DIR/windows-export.log"

log "Booting exported Linux binary headless"
HOME="$SMOKE_HOME" \
XDG_CONFIG_HOME="$GODOT_EXPORT_CONFIG_HOME" \
    "$LINUX_DIR/SpaceWheat.x86_64" --headless --quit-after 240 >"$LINUX_LOG" 2>&1

grep -qi "ComplexMatrix.*native acceleration enabled" "$LINUX_LOG" || error "Linux export did not report native matrix acceleration"
if ! grep -q "Native lookahead active:" "$LINUX_LOG"; then
    grep -q "Lookahead buffers primed" "$LINUX_LOG" || error "Linux export did not activate the native lookahead engine"
fi

success "Linux export booted with native acceleration"

case "$WINDOWS_SMOKE_MODE" in
    skip)
        success "Windows export package contains executable + native DLL"
        ;;
    native)
        command -v powershell.exe >/dev/null 2>&1 || error "WINDOWS_SMOKE_MODE=native requires powershell.exe from WSL interop"
        log "Booting exported Windows binary headless via Windows runtime"
        WINDOWS_EXE="$(sw_wsl_to_windows_path "$WINDOWS_DIR/SpaceWheat.exe")"
        WINDOWS_LOG_WIN="$(sw_wsl_to_windows_path "$WINDOWS_LOG")"
        powershell.exe -NoProfile -NonInteractive -Command "\$p = Start-Process -FilePath '$WINDOWS_EXE' -ArgumentList '--headless', '--quit-after', '240' -Wait -PassThru -RedirectStandardOutput '$WINDOWS_LOG_WIN' -RedirectStandardError '$WINDOWS_LOG_WIN'; exit \$p.ExitCode" >/dev/null 2>&1
        grep -qi "ComplexMatrix.*native acceleration enabled" "$WINDOWS_LOG" || error "Windows export did not report native matrix acceleration"
        if ! grep -q "Native lookahead active:" "$WINDOWS_LOG"; then
            grep -q "Lookahead buffers primed" "$WINDOWS_LOG" || error "Windows export did not activate the native lookahead engine"
        fi
        success "Windows export booted with native acceleration"
        ;;
    *)
        error "Unknown WINDOWS_SMOKE_MODE: $WINDOWS_SMOKE_MODE (use: skip, native)"
        ;;
esac

echo ""
echo "Artifacts checked:"
echo "  Linux:   $LINUX_DIR"
echo "  Windows: $WINDOWS_DIR"
echo "  Log:     $LINUX_LOG"
if [ "$WINDOWS_SMOKE_MODE" = "native" ]; then
    echo "  Win log: $WINDOWS_LOG"
fi
