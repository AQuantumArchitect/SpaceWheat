#!/usr/bin/env bash

# launch-linux-editor.sh - Launch the Godot editor for this project with the
# same WSL-aware runtime environment used by the desktop launch wrappers.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source "$PROJECT_DIR/scripts/lib/godot_runtime_env.sh"

show_help() {
    cat << 'EOF'
Launch the Godot editor for the SpaceWheat project with WSL-aware audio/video.

Usage:
  ./scripts/launch-linux-editor.sh [OPTIONS] [-- <args...>]

Options:
  --log-file PATH      Tee launcher + editor output to a log file
  --help               Show this help

Any extra arguments after -- are passed to Godot editor.
EOF
}

BOOT_LOG_FILE="${SW_BOOT_LOG_FILE:-}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            show_help
            exit 0
            ;;
        --log-file)
            BOOT_LOG_FILE="$2"
            shift 2
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

if [ -z "${SW_FORCE_AUDIO_DRIVER+x}" ]; then
    export SW_FORCE_AUDIO_DRIVER=Dummy
fi

if [ -n "$BOOT_LOG_FILE" ]; then
    mkdir -p "$(dirname "$BOOT_LOG_FILE")"
    exec > >(tee -a "$BOOT_LOG_FILE") 2>&1
    printf '[launch] logging to %s\n' "$BOOT_LOG_FILE"
fi

sw_prepare_runtime_env "interactive"

cd "$PROJECT_DIR"
sw_godot -e --path "$PROJECT_DIR" "$@"
