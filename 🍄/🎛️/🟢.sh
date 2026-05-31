#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
source "${PROJECT_ROOT}/scripts/lib/godot_runtime_env.sh"
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
export RIG_DISABLE_LOOKAHEAD=1  # C++ MultiBiomeLookaheadEngine crashes on mixed qubit dims (6D+4D); re-enable when fixed
export RIG_DISABLE_MI=1
export RIG_DISABLE_FORCE=1
RIG_DISPLAY_MODE="${RIG_DISPLAY_MODE:-headless}"
RIG_RENDERING_DRIVER="${RIG_RENDERING_DRIVER:-}"
if [ "$RIG_DISPLAY_MODE" = "headed" ]; then
  sw_prepare_runtime_env "interactive"
  if [ -z "$RIG_RENDERING_DRIVER" ] && sw_is_wsl; then
    # WSL headed Vulkan currently falls onto llvmpipe and never reaches Rig ready.
    RIG_RENDERING_DRIVER="opengl3"
  fi
else
  sw_prepare_runtime_env "headless"
fi

echo "Starting live rig listener..."
echo "Queue:  user://rig/queue.jsonl"
echo "Results: user://rig/results.jsonl"
echo "User dir: $GODOT_USER_DIR"
echo "Display mode: $RIG_DISPLAY_MODE"
if [ -n "$RIG_RENDERING_DRIVER" ]; then
  echo "Rendering driver: $RIG_RENDERING_DRIVER"
fi

if [ "$RIG_DISPLAY_MODE" = "headed" ]; then
  if [ -n "$RIG_RENDERING_DRIVER" ]; then
    sw_godot --rendering-driver "$RIG_RENDERING_DRIVER" --path . --script Rig/rig_listener.gd
  else
    sw_godot --path . --script Rig/rig_listener.gd
  fi
else
  sw_godot --headless --path . --script Rig/rig_listener.gd
fi
