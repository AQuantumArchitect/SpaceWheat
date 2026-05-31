#!/bin/bash
# launch-linux-desktop.sh - Launch the latest Linux desktop export with the
# same WSL-aware runtime environment used by the profiling and smoke scripts.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source "$PROJECT_DIR/scripts/lib/godot_runtime_env.sh"

EXPORT_ROOT="${EXPORT_ROOT:-$PROJECT_DIR/releases/local/linux-native}"
LINUX_EXE="$EXPORT_ROOT/SpaceWheat.x86_64"

show_help() {
    cat << 'EOF'
Launch the latest Linux desktop export.

Usage:
  ./scripts/launch-linux-desktop.sh [OPTIONS] [-- <args...>]

Options:
  --export-root PATH   Export folder (default: ./releases/local/linux-native)
  --log-file PATH      Tee launcher + game output to a log file
  --help               Show this help

Any extra arguments after -- are passed to SpaceWheat.x86_64.
EOF
}

BOOT_LOG_FILE="${SW_BOOT_LOG_FILE:-}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --export-root)
            EXPORT_ROOT="$2"
            LINUX_EXE="$EXPORT_ROOT/SpaceWheat.x86_64"
            shift 2
            ;;
        --log-file)
            BOOT_LOG_FILE="$2"
            shift 2
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        --)
            shift
            break
            ;;
        *)
            break
            ;;
    esac
done

if [ ! -x "$LINUX_EXE" ]; then
    printf 'Missing Linux export executable: %s\n' "$LINUX_EXE" >&2
    exit 1
fi

if [ -n "$BOOT_LOG_FILE" ]; then
    mkdir -p "$(dirname "$BOOT_LOG_FILE")"
    exec > >(tee -a "$BOOT_LOG_FILE") 2>&1
    printf '[launch] logging to %s\n' "$BOOT_LOG_FILE"
fi

sw_prepare_runtime_env "interactive"

if [ -z "${VERBOSE_LOG_PATH:-}" ]; then
    export VERBOSE_LOG_PATH="${XDG_DATA_HOME:-$HOME/.local/share}/SpaceWheat/logs"
    mkdir -p "$VERBOSE_LOG_PATH"
fi

has_audio_arg=0
for arg in "$@"; do
    if [ "$arg" = "--audio-driver" ]; then
        has_audio_arg=1
        break
    fi
done

cd "$EXPORT_ROOT"
if [ "$has_audio_arg" -eq 0 ]; then
    exec "$LINUX_EXE" --audio-driver "${SW_GODOT_AUDIO_DRIVER:-Dummy}" "$@"
fi
exec "$LINUX_EXE" "$@"
