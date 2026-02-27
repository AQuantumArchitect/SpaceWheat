#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
XDG_ROOT="${XDG_ROOT:-${PROJECT_ROOT}/.godot}"
APPLICATION_NAME="${APPLICATION_NAME:-SpaceWheat - Quantum Farm}"
# Godot resolves user:// under $XDG_DATA_HOME/godot/app_userdata/<AppName>
GODOT_USER_DIR="${GODOT_USER_DIR:-${XDG_ROOT}/godot/app_userdata/${APPLICATION_NAME}}"

mkdir -p "$GODOT_USER_DIR/rig"

# Clear queue so stale turns (e.g. "stop") from previous session don't replay
> "$GODOT_USER_DIR/rig/queue.jsonl"

cd "$PROJECT_ROOT"
export XDG_DATA_HOME="$XDG_ROOT"
export XDG_CONFIG_HOME="$XDG_ROOT"
export APPLICATION_NAME
export GODOT_USER_DIR
export DISABLE_VERBOSE_FILE_LOGGING=1
# RIG_DISABLE_LOOKAHEAD removed — use C++ MultiBiomeLookaheadEngine when available
export RIG_DISABLE_MI=1
export RIG_DISABLE_FORCE=1

echo "Starting live rig listener..."
echo "Queue:  user://rig/queue.jsonl"
echo "Results: user://rig/results.jsonl"
echo "User dir: $GODOT_USER_DIR"

exec godot --headless --path . --script Tests/rig_listener.gd
