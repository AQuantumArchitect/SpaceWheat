#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$(realpath "$0")")"
source "$(pwd)/scripts/lib/godot_runtime_env.sh"

# Optional: export any env vars (e.g., for headless testing)
# export GODOT_HEADLESS=1

# Prepare log directory
LOG_DIR="$(pwd)/tests/logs"
mkdir -p "$LOG_DIR"
# Override VerboseConfig log path so Godot doesn’t try to write to user://
export VERBOSE_LOG_PATH="$LOG_DIR"
sw_prepare_runtime_env "headless"
# Launch Godot with the project, directing logs to tests/logs/godot.log
sw_godot --headless --log-file "$LOG_DIR/godot.log" --path . "$@"
